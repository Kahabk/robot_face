import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'robot_transport.dart';

/// WebSocket transport implementation with automatic reconnection
class WebSocketTransport implements RobotTransport {
  final String url;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;
  final void Function(Map<String, dynamic>)? onMessage;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _heartbeatInterval = Duration(seconds: 15);

  WebSocketTransport({
    required this.url,
    this.onConnected,
    this.onDisconnected,
    this.onMessage,
  });

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    _shouldReconnect = true;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    try {
      debugPrint('[WebSocket] Connecting to $url');
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _subscription = _channel!.stream.listen(
        (data) {
          if (!_isConnected) {
            _isConnected = true;
            _startHeartbeat();
            onConnected?.call();
          }
          _handleMessage(data);
        },
        onError: (error) {
          debugPrint('[WebSocket] Error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[WebSocket] Connection closed');
          _handleDisconnect();
        },
        cancelOnError: false,
      );

      // Wait briefly to see if connection is established
      await Future.delayed(const Duration(milliseconds: 500));
      if (_channel != null) {
        _isConnected = true;
        _startHeartbeat();
        onConnected?.call();
        debugPrint('[WebSocket] Connected to $url');
      }
    } catch (e) {
      debugPrint('[WebSocket] Connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final decoded = json.decode(data as String) as Map<String, dynamic>;
      onMessage?.call(decoded);
    } catch (e) {
      debugPrint('[WebSocket] Failed to parse message: $e');
    }
  }

  void _handleDisconnect() {
    if (_isConnected) {
      _isConnected = false;
      _stopHeartbeat();
      onDisconnected?.call();
    }
    _subscription?.cancel();
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_shouldReconnect) {
        _doConnect();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_isConnected) {
        send({'type': 'ping', 'timestamp': DateTime.now().millisecondsSinceEpoch});
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  Future<void> send(Map<String, dynamic> data) async {
    if (!_isConnected || _channel == null) return;
    try {
      _channel!.sink.add(json.encode(data));
    } catch (e) {
      debugPrint('[WebSocket] Send failed: $e');
    }
  }

  @override
  Stream<Map<String, dynamic>> get messages => _channel?.stream
          .map((data) {
            try {
              return json.decode(data as String) as Map<String, dynamic>;
            } catch (_) {
              return <String, dynamic>{};
            }
          })
          .where((m) => m.isNotEmpty) ??
      const Stream.empty();

  @override
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }
}

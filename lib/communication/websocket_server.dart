import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../robot/robot_controller.dart';
import 'command_parser.dart';

/// WebSocket server running on the tablet
/// Allows the robot backend to connect to the tablet and send commands
class WebSocketServerTransport {
  final int port;
  final RobotController controller;
  final CommandParser commandParser;

  HttpServer? _server;
  final List<WebSocket> _clients = [];
  bool _running = false;

  WebSocketServerTransport({
    required this.controller,
    required this.commandParser,
    this.port = 8081,
  });

  bool get isRunning => _running;
  int get clientCount => _clients.length;

  Future<void> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _running = true;
      debugPrint('[WSServer] Listening on port $port');
      _acceptConnections();
    } catch (e) {
      debugPrint('[WSServer] Failed to start: $e');
    }
  }

  Future<void> _acceptConnections() async {
    if (_server == null) return;

    await for (final request in _server!) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        _handleWebSocket(request);
      } else {
        request.response.statusCode = 400;
        request.response.close();
      }
    }
  }

  Future<void> _handleWebSocket(HttpRequest request) async {
    try {
      final ws = await WebSocketTransformer.upgrade(request);
      _clients.add(ws);
      debugPrint('[WSServer] Client connected (${_clients.length} total)');

      // Send welcome/status
      _sendToClient(ws, controller.getStatus()..['type'] = 'status');

      ws.listen(
        (data) {
          try {
            final decoded = json.decode(data as String) as Map<String, dynamic>;
            commandParser.parse(decoded);

            // Acknowledge
            _sendToClient(ws, {'type': 'ack', 'received': decoded['type']});
          } catch (e) {
            debugPrint('[WSServer] Parse error: $e');
            _sendToClient(ws, {'type': 'error', 'message': 'Invalid JSON'});
          }
        },
        onDone: () {
          _clients.remove(ws);
          debugPrint('[WSServer] Client disconnected (${_clients.length} remaining)');
        },
        onError: (error) {
          _clients.remove(ws);
          debugPrint('[WSServer] Client error: $error');
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[WSServer] WebSocket upgrade failed: $e');
    }
  }

  void _sendToClient(WebSocket ws, Map<String, dynamic> data) {
    try {
      ws.add(json.encode(data));
    } catch (e) {
      debugPrint('[WSServer] Send failed: $e');
    }
  }

  /// Broadcast state updates to all connected clients
  void broadcast(Map<String, dynamic> data) {
    final encoded = json.encode(data);
    final deadClients = <WebSocket>[];

    for (final client in _clients) {
      try {
        client.add(encoded);
      } catch (e) {
        deadClients.add(client);
      }
    }

    for (final dead in deadClients) {
      _clients.remove(dead);
    }
  }

  Future<void> stop() async {
    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    _running = false;
  }
}

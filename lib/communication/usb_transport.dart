import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

import 'robot_transport.dart';

/// USB Serial transport for Android tablet communication
class UsbTransport implements RobotTransport {
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;
  final void Function(Map<String, dynamic>)? onMessage;

  UsbPort? _port;
  StreamSubscription? _subscription;
  StreamSubscription? _deviceSubscription;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  Timer? _reconnectTimer;

  // Buffer for incoming data (JSON may come in chunks)
  String _buffer = '';

  static const int _baudRate = 115200;
  static const Duration _reconnectDelay = Duration(seconds: 2);

  UsbTransport({
    this.onConnected,
    this.onDisconnected,
    this.onMessage,
  });

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    _shouldReconnect = true;
    // Delay 2s — lets the face render first before native USB code initializes
    Future.delayed(const Duration(seconds: 2), () {
      _listenForDevices();
      _doConnect();
    });
  }

  void _listenForDevices() {
    try {
      _deviceSubscription = UsbSerial.usbEventStream?.listen(
        (event) {
          try {
            debugPrint('[USB] Event: ${event.event}');
            if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
              Future.delayed(const Duration(milliseconds: 500), _doConnect);
            } else if (event.event == UsbEvent.ACTION_USB_DETACHED) {
              _handleDisconnect();
            }
          } catch (e) {
            debugPrint('[USB] Event handler error: $e');
          }
        },
        onError: (e) => debugPrint('[USB] Stream error: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[USB] Could not subscribe to USB events: $e');
    }
  }

  Future<void> _doConnect() async {
    if (_isConnected) return;

    try {
      final ports = await UsbSerial.listDevices();
      debugPrint('[USB] Scanning... found ${ports.length} device(s)');

      if (ports.isEmpty) {
        debugPrint('[USB] No devices found — will retry in ${_reconnectDelay.inSeconds}s');
        _scheduleReconnect();
        return;
      }

      for (final device in ports) {
        debugPrint('[USB] ┌── Device: ${device.productName}');
        debugPrint('[USB] │   VID: 0x${device.vid?.toRadixString(16).toUpperCase()}'
            '  PID: 0x${device.pid?.toRadixString(16).toUpperCase()}');
        debugPrint('[USB] │   Manufacturer: ${device.manufacturerName}');

        try {
          _port = await device.create();
          if (_port == null) {
            debugPrint('[USB] └── Could not create port for ${device.productName}');
            continue;
          }

          final opened = await _port!.open();
          if (!opened) {
            debugPrint('[USB] └── Failed to open port for ${device.productName}');
            _port = null;
            continue;
          }

          await _port!.setDTR(true);
          await _port!.setRTS(true);
          await _port!.setPortParameters(
            _baudRate,
            UsbPort.DATABITS_8,
            UsbPort.STOPBITS_1,
            UsbPort.PARITY_NONE,
          );
          debugPrint('[USB] │   Baud: $_baudRate  8N1  DTR/RTS=true');

          _isConnected = true;
          _buffer = '';
          debugPrint('[USB] └── CONNECTED to ${device.productName} ✓');
          onConnected?.call();

          // Listen for incoming data
          _subscription = _port!.inputStream?.listen(
            _handleData,
            onError: (error) {
              debugPrint('[USB] Read error: $error');
              _handleDisconnect();
            },
            onDone: () {
              debugPrint('[USB] Stream closed');
              _handleDisconnect();
            },
            cancelOnError: false,
          );

          break; // Successfully connected
        } catch (e) {
          debugPrint('[USB] └── Failed to connect to device: $e');
          _port = null;
        }
      }

      if (!_isConnected) {
        _scheduleReconnect();
      }
    } catch (e) {
      debugPrint('[USB] Connect error: $e');
      _scheduleReconnect();
    }
  }

  void _handleData(Uint8List data) {
    _buffer += String.fromCharCodes(data);
    debugPrint('[USB] <<< raw ${data.lengthInBytes} bytes  buffer=${_buffer.length}');

    while (true) {
      final newlineIndex = _buffer.indexOf('\n');
      if (newlineIndex == -1) break;

      final line = _buffer.substring(0, newlineIndex).trim();
      _buffer = _buffer.substring(newlineIndex + 1);

      if (line.isEmpty) continue;

      try {
        final decoded = json.decode(line) as Map<String, dynamic>;
        debugPrint('[USB] <<< CMD: $decoded');
        onMessage?.call(decoded);
      } catch (e) {
        debugPrint('[USB] ✗ Parse failed: "$line"  error: $e');
      }
    }

    if (_buffer.length > 65536) {
      debugPrint('[USB] ⚠ Buffer overflow (${_buffer.length} bytes) — clearing');
      _buffer = '';
    }
  }

  void _handleDisconnect() {
    if (_isConnected) {
      _isConnected = false;
      onDisconnected?.call();
    }
    _subscription?.cancel();
    _port?.close();
    _port = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_shouldReconnect && !_isConnected) {
        _doConnect();
      }
    });
  }

  @override
  Future<void> send(Map<String, dynamic> data) async {
    if (!_isConnected || _port == null) {
      debugPrint('[USB] >>> SEND skipped (not connected): $data');
      return;
    }
    try {
      final jsonStr = '${json.encode(data)}\n';
      debugPrint('[USB] >>> ${jsonStr.trim()}');
      await _port!.write(Uint8List.fromList(jsonStr.codeUnits));
    } catch (e) {
      debugPrint('[USB] >>> Send failed: $e');
    }
  }

  @override
  Stream<Map<String, dynamic>> get messages => const Stream.empty();

  @override
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _deviceSubscription?.cancel();
    await _subscription?.cancel();
    await _port?.close();
    _port = null;
    _isConnected = false;
  }
}

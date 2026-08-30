import 'package:flutter/foundation.dart';

import '../robot/emotion.dart';
import '../communication/command_parser.dart';
import '../communication/websocket_server.dart';
import '../communication/rest_client.dart';
import '../communication/usb_transport.dart';
import '../communication/websocket_transport.dart';
import '../settings/device_config.dart';

/// Central robot controller that manages state and coordinates communication
class RobotController extends ChangeNotifier {
  final DeviceConfig config;

  // Current state
  RobotEmotion _currentEmotion = RobotEmotion.neutral;
  RobotState _currentState = RobotState.idle;
  EyeDirection _eyeDirection = EyeDirection.center;
  bool _isTalking = false;
  bool _isBlinking = false;

  // Connection status
  bool _usbConnected = false;
  bool _wsConnected = false;

  // Transports
  WebSocketTransport? _wsClientTransport;
  WebSocketServerTransport? _wsServer;
  RestApiServer? _restServer;
  UsbTransport? _usbTransport;

  // Command parser
  late final CommandParser _commandParser;

  RobotController({required this.config}) {
    _commandParser = CommandParser(controller: this);
  }

  // --- Getters ---
  RobotEmotion get currentEmotion => _currentEmotion;
  RobotState get currentState => _currentState;
  EyeDirection get eyeDirection => _eyeDirection;
  bool get isTalking => _isTalking;
  bool get isBlinking => _isBlinking;
  bool get usbConnected => _usbConnected;
  bool get wsConnected => _wsConnected;

  /// Initialize all transports
  Future<void> initialize() async {
    await Future.wait([
      _initWsServer(),
      _initRestServer(),
      _initWsClient(),
      _initUsb(),
    ]);
  }

  Future<void> _initWsServer() async {
    try {
      _wsServer = WebSocketServerTransport(
        controller: this,
        commandParser: _commandParser,
        port: 8081,
      );
      await _wsServer!.start();
      _wsConnected = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[Robot] WS Server init failed: $e');
    }
  }

  Future<void> _initRestServer() async {
    try {
      _restServer = RestApiServer(
        controller: this,
        commandParser: _commandParser,
        port: 8082,
      );
      await _restServer!.start();
    } catch (e) {
      debugPrint('[Robot] REST Server init failed: $e');
    }
  }

  Future<void> _initWsClient() async {
    // Only connect as WS client if a backend URL is configured
    if (config.wsUrl.isEmpty) return;
    try {
      _wsClientTransport = WebSocketTransport(
        url: config.wsUrl,
        onConnected: () {
          notifyListeners();
        },
        onDisconnected: () {
          notifyListeners();
        },
        onMessage: (data) => _commandParser.parse(data),
      );
      await _wsClientTransport!.connect();
    } catch (e) {
      debugPrint('[Robot] WebSocket client init failed: $e');
    }
  }

  Future<void> _initUsb() async {
    try {
      _usbTransport = UsbTransport(
        onConnected: () {
          _usbConnected = true;
          notifyListeners();
        },
        onDisconnected: () {
          _usbConnected = false;
          notifyListeners();
        },
        onMessage: (data) => _commandParser.parse(data),
      );
      await _usbTransport!.connect();
    } catch (e) {
      debugPrint('[Robot] USB init failed: $e');
    }
  }

  // --- Command Handlers ---

  void setEmotion(RobotEmotion emotion, {int? durationMs}) {
    _currentEmotion = emotion;

    switch (emotion) {
      case RobotEmotion.talking:
        _currentState = RobotState.talking;
        _isTalking = true;
        break;
      case RobotEmotion.listening:
        _currentState = RobotState.listening;
        _isTalking = false;
        break;
      case RobotEmotion.thinking:
        _currentState = RobotState.thinking;
        _isTalking = false;
        break;
      case RobotEmotion.sleep:
        _currentState = RobotState.sleeping;
        _isTalking = false;
        break;
      case RobotEmotion.error:
        _currentState = RobotState.error;
        _isTalking = false;
        break;
      default:
        _currentState = RobotState.idle;
        _isTalking = false;
    }

    notifyListeners();

    if (durationMs != null && durationMs > 0) {
      Future.delayed(Duration(milliseconds: durationMs), () {
        if (_currentEmotion == emotion) {
          setEmotion(RobotEmotion.neutral);
        }
      });
    }
  }

  void setState(RobotState state) {
    _currentState = state;

    switch (state) {
      case RobotState.talking:
        _currentEmotion = RobotEmotion.talking;
        _isTalking = true;
        break;
      case RobotState.listening:
        _currentEmotion = RobotEmotion.listening;
        _isTalking = false;
        break;
      case RobotState.thinking:
        _currentEmotion = RobotEmotion.thinking;
        _isTalking = false;
        break;
      case RobotState.sleeping:
        _currentEmotion = RobotEmotion.sleep;
        _isTalking = false;
        break;
      case RobotState.error:
        _currentEmotion = RobotEmotion.error;
        _isTalking = false;
        break;
      case RobotState.idle:
        _currentEmotion = RobotEmotion.neutral;
        _isTalking = false;
        break;
    }

    notifyListeners();
  }

  void setTalking(bool talking) {
    _isTalking = talking;
    if (talking) {
      _currentEmotion = RobotEmotion.talking;
      _currentState = RobotState.talking;
    } else {
      _currentEmotion = RobotEmotion.neutral;
      _currentState = RobotState.idle;
    }
    notifyListeners();
  }

  void triggerBlink() {
    _isBlinking = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 300), () {
      _isBlinking = false;
      notifyListeners();
    });
  }

  void lookDirection(String direction) {
    switch (direction.toLowerCase()) {
      case 'left':
        _eyeDirection = EyeDirection.left;
        break;
      case 'right':
        _eyeDirection = EyeDirection.right;
        break;
      case 'up':
        _eyeDirection = EyeDirection.up;
        break;
      case 'down':
        _eyeDirection = EyeDirection.down;
        break;
      default:
        _eyeDirection = EyeDirection.center;
    }
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1500), () {
      _eyeDirection = EyeDirection.center;
      notifyListeners();
    });
  }

  void reset() {
    _currentEmotion = RobotEmotion.neutral;
    _currentState = RobotState.idle;
    _eyeDirection = EyeDirection.center;
    _isTalking = false;
    _isBlinking = false;
    notifyListeners();
  }

  Map<String, dynamic> getStatus() {
    return {
      'connected': _usbConnected || _wsConnected,
      'usb_connected': _usbConnected,
      'ws_connected': _wsConnected,
      'ws_server_running': _wsServer?.isRunning ?? false,
      'rest_server_running': _restServer?.isRunning ?? false,
      'emotion': _currentEmotion.name,
      'state': _currentState.name,
      'talking': _isTalking,
      'eye_direction': _eyeDirection.name,
    };
  }

  @override
  void dispose() {
    _wsClientTransport?.disconnect();
    _wsServer?.stop();
    _restServer?.stop();
    _usbTransport?.disconnect();
    super.dispose();
  }
}

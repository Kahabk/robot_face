import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-level configuration for the robot face
class DeviceConfig extends ChangeNotifier {
  static const String _wsUrlKey = 'ws_url';
  static const String _devModeKey = 'dev_mode';
  static const String _orientationKey = 'orientation';

  String _wsUrl = ''; // Empty = don't auto-connect as WS client
  bool _devMode = false;
  String _orientation = 'landscape';

  DeviceConfig() {
    _load();
  }

  String get wsUrl => _wsUrl;
  bool get devMode => _devMode;
  String get orientation => _orientation;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _wsUrl = prefs.getString(_wsUrlKey) ?? _wsUrl;
      _devMode = prefs.getBool(_devModeKey) ?? false;
      _orientation = prefs.getString(_orientationKey) ?? _orientation;
      notifyListeners();
    } catch (e) {
      debugPrint('[Config] Load failed: $e');
    }
  }

  Future<void> setWsUrl(String url) async {
    _wsUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wsUrlKey, url);
    notifyListeners();
  }

  Future<void> setDevMode(bool value) async {
    _devMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_devModeKey, value);
    notifyListeners();
  }
}

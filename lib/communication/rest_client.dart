import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../robot/robot_controller.dart';
import 'command_parser.dart';

/// REST API server that runs on the tablet and receives commands
/// This makes the tablet accessible from the robot backend over WiFi
class RestApiServer {
  final RobotController controller;
  final CommandParser commandParser;
  final int port;

  HttpServer? _server;
  bool _running = false;

  RestApiServer({
    required this.controller,
    required this.commandParser,
    this.port = 8082,
  });

  bool get isRunning => _running;

  Future<void> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _running = true;
      debugPrint('[REST] Server listening on port $port');
      _handleRequests();
    } catch (e) {
      debugPrint('[REST] Failed to start server: $e');
    }
  }

  Future<void> _handleRequests() async {
    if (_server == null) return;

    await for (final request in _server!) {
      _processRequest(request);
    }
  }

  Future<void> _processRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    // CORS headers for development
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');
    request.response.headers.contentType = ContentType.json;

    if (method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    try {
      Map<String, dynamic> body = {};
      if (method == 'POST') {
        final bodyStr = await utf8.decodeStream(request);
        if (bodyStr.isNotEmpty) {
          body = json.decode(bodyStr) as Map<String, dynamic>;
        }
      }

      if (method == 'GET' && path == '/api/robot/status') {
        _respond(request, controller.getStatus());
      } else if (method == 'GET' && path == '/api/robot/state') {
        _respond(request, {
          'emotion': controller.currentEmotion.name,
          'state': controller.currentState.name,
          'talking': controller.isTalking,
          'eye_direction': controller.eyeDirection.name,
        });
      } else if (method == 'POST' && path == '/api/robot/emotion') {
        commandParser.parse({'type': 'emotion', ...body});
        _respond(request, {'ok': true});
      } else if (method == 'POST' && path == '/api/robot/state') {
        commandParser.parse({'type': 'state', ...body});
        _respond(request, {'ok': true});
      } else if (method == 'POST' && path == '/api/robot/speak') {
        commandParser.parse({'type': 'speech', ...body});
        _respond(request, {'ok': true});
      } else if (method == 'POST' && path == '/api/robot/eyes') {
        commandParser.parse({'type': 'eyes', ...body});
        _respond(request, {'ok': true});
      } else if (method == 'POST' && path == '/api/robot/mouth') {
        commandParser.parse({'type': 'mouth', ...body});
        _respond(request, {'ok': true});
      } else if (method == 'POST' && path == '/api/robot/blink') {
        commandParser.parse({'type': 'blink'});
        _respond(request, {'ok': true});
      } else if (method == 'POST' && path == '/api/robot/look') {
        commandParser.parse({'type': 'look', ...body});
        _respond(request, {'ok': true});
      } else if (method == 'POST' && path == '/api/robot/reset') {
        commandParser.parse({'type': 'reset'});
        _respond(request, {'ok': true});
      } else {
        request.response.statusCode = 404;
        _respond(request, {'error': 'Not found', 'path': path});
      }
    } catch (e) {
      request.response.statusCode = 500;
      _respond(request, {'error': e.toString()});
    }
  }

  void _respond(HttpRequest request, Map<String, dynamic> data) {
    request.response
      ..write(json.encode(data))
      ..close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _running = false;
  }
}

/// REST API client for robot backend (Python/Node.js backend calling tablet)
class RestApiClient {
  final String baseUrl;
  final http.Client _client = http.Client();

  RestApiClient({required this.baseUrl});

  Future<Map<String, dynamic>> getStatus() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/robot/status'));
    return json.decode(response.body) as Map<String, dynamic>;
  }

  Future<bool> setEmotion(String emotion, {int? duration}) async {
    final body = {'emotion': emotion, if (duration != null) 'duration': duration};
    final response = await _client.post(
      Uri.parse('$baseUrl/api/robot/emotion'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    return response.statusCode == 200;
  }

  Future<bool> setState(String state) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/robot/state'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'state': state}),
    );
    return response.statusCode == 200;
  }

  Future<bool> speak(String text) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/robot/speak'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'text': text}),
    );
    return response.statusCode == 200;
  }

  Future<bool> blink() async {
    final response = await _client.post(Uri.parse('$baseUrl/api/robot/blink'));
    return response.statusCode == 200;
  }

  Future<bool> look(String direction) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/robot/look'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'direction': direction}),
    );
    return response.statusCode == 200;
  }

  void dispose() => _client.close();
}

import 'package:flutter/foundation.dart';

import '../robot/emotion.dart';
import '../robot/robot_controller.dart';

/// Parses incoming JSON commands from any transport and dispatches to controller
class CommandParser {
  final RobotController controller;

  CommandParser({required this.controller});

  void parse(Map<String, dynamic> data) {
    try {
      final type = data['type'] as String?;
      if (type == null) return;

      switch (type) {
        case 'emotion':
          _handleEmotion(data);
          break;
        case 'state':
          _handleState(data);
          break;
        case 'eyes':
          _handleEyes(data);
          break;
        case 'mouth':
          _handleMouth(data);
          break;
        case 'look':
          _handleLook(data);
          break;
        case 'blink':
          controller.triggerBlink();
          break;
        case 'talk':
          _handleTalk(data);
          break;
        case 'speech':
          _handleSpeech(data);
          break;
        case 'animation':
          _handleAnimation(data);
          break;
        case 'reset':
          controller.reset();
          break;
        default:
          debugPrint('[CommandParser] Unknown command type: $type');
      }
    } catch (e) {
      debugPrint('[CommandParser] Error parsing command: $e, data: $data');
    }
  }

  void _handleEmotion(Map<String, dynamic> data) {
    final emotionStr = data['emotion'] as String?;
    if (emotionStr == null) return;

    final emotion = _parseEmotion(emotionStr);
    if (emotion == null) {
      debugPrint('[CommandParser] Unknown emotion: $emotionStr');
      return;
    }

    final duration = data['duration'] as int?;
    controller.setEmotion(emotion, durationMs: duration);
  }

  void _handleState(Map<String, dynamic> data) {
    final stateStr = data['state'] as String?;
    if (stateStr == null) return;

    final state = _parseState(stateStr);
    if (state == null) {
      // Try as emotion
      final emotion = _parseEmotion(stateStr);
      if (emotion != null) {
        controller.setEmotion(emotion);
      }
      return;
    }

    controller.setState(state);
  }

  void _handleEyes(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    if (action == null) return;

    switch (action) {
      case 'blink':
        controller.triggerBlink();
        break;
      case 'look':
        final direction = data['direction'] as String? ?? 'center';
        controller.lookDirection(direction);
        break;
    }
  }

  void _handleMouth(Map<String, dynamic> data) {
    // Mouth-specific commands can be added here
    // For now, map to emotions
    final shape = data['shape'] as String?;
    if (shape == null) return;

    if (shape == 'talking' || shape == 'open') {
      controller.setTalking(true);
    } else {
      controller.setTalking(false);
    }
  }

  void _handleLook(Map<String, dynamic> data) {
    final direction = data['direction'] as String? ?? 'center';
    controller.lookDirection(direction);
  }

  void _handleTalk(Map<String, dynamic> data) {
    final enabled = data['enabled'] as bool? ?? true;
    controller.setTalking(enabled);
  }

  void _handleSpeech(Map<String, dynamic> data) {
    // When receiving speech text, trigger talking animation
    final text = data['text'] as String?;
    if (text != null && text.isNotEmpty) {
      controller.setTalking(true);
      // Estimate duration based on word count (roughly 150wpm)
      final words = text.split(' ').length;
      final durationMs = (words / 150 * 60 * 1000).round();
      Future.delayed(Duration(milliseconds: durationMs.clamp(500, 30000)), () {
        controller.setTalking(false);
      });
    }
  }

  void _handleAnimation(Map<String, dynamic> data) {
    final name = data['name'] as String?;
    if (name == null) return;

    // Map animation names to emotions/actions
    switch (name) {
      case 'blink':
        controller.triggerBlink();
        break;
      case 'nod':
        controller.lookDirection('up');
        Future.delayed(const Duration(milliseconds: 300), () {
          controller.lookDirection('down');
          Future.delayed(const Duration(milliseconds: 300), () {
            controller.lookDirection('center');
          });
        });
        break;
      default:
        final emotion = _parseEmotion(name);
        if (emotion != null) {
          final duration = data['duration'] as int?;
          controller.setEmotion(emotion, durationMs: duration);
        }
    }
  }

  RobotEmotion? _parseEmotion(String s) {
    for (final e in RobotEmotion.values) {
      if (e.name.toLowerCase() == s.toLowerCase()) return e;
    }
    return null;
  }

  RobotState? _parseState(String s) {
    for (final e in RobotState.values) {
      if (e.name.toLowerCase() == s.toLowerCase()) return e;
    }
    return null;
  }
}

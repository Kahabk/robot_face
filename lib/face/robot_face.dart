import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../robot/robot_controller.dart';
import 'emotion_controller.dart';
import 'face_renderer.dart';
import 'face_tracker.dart';

/// Top-level robot face widget.
/// Owns EmotionController (animation) and FaceTracker (camera).
class RobotFace extends StatefulWidget {
  const RobotFace({super.key});

  @override
  State<RobotFace> createState() => _RobotFaceState();
}

class _RobotFaceState extends State<RobotFace> with TickerProviderStateMixin {
  late EmotionController _emotionController;
  final FaceTracker _faceTracker = FaceTracker();
  StreamSubscription<dynamic>? _trackSub;

  // Small status shown in corner when face tracking is active
  bool _trackingActive = false;

  @override
  void initState() {
    super.initState();
    _emotionController = EmotionController(vsync: this);
    _startFaceTracking();
  }

  // ── Face tracking ─────────────────────────────────────────

  Future<void> _startFaceTracking() async {
    // Request camera permission gracefully
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        debugPrint('[RobotFace] Camera permission denied — face tracking off');
        return;
      }
    } catch (e) {
      debugPrint('[RobotFace] Permission error: $e');
      return;
    }

    await _faceTracker.start();

    _trackSub = _faceTracker.positionStream.listen(
      (FacePosition pos) {
        if (!mounted) return;

        final bool hasFace = pos.x != 0.0 || pos.y != 0.0;

        if (hasFace) {
          _emotionController.setFaceTarget(pos.x, pos.y);
        } else {
          _emotionController.clearFaceTarget();
        }

        if (_trackingActive != hasFace) {
          setState(() => _trackingActive = hasFace);
        }
      },
      onError: (e) => debugPrint('[RobotFace] Track stream error: $e'),
    );
  }

  @override
  void dispose() {
    _trackSub?.cancel();
    _faceTracker.dispose();
    _emotionController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final robotController = context.watch<RobotController>();

    // Sync emotion + talking state from the high-level robot controller
    _emotionController.setEmotion(
      robotController.currentEmotion,
      eyeDirection: robotController.eyeDirection,
      isTalking:    robotController.isTalking,
      forceBlink:   robotController.isBlinking,
    );

    return Stack(
      children: [
        // Full-screen animated face
        Container(
          color: Colors.black,
          child: FaceRenderer(emotionController: _emotionController),
        ),

        // Tiny "face tracking" indicator (bottom-right, debug only)
        if (_trackingActive)
          Positioned(
            bottom: 8,
            right: 8,
            child: _FaceTrackDot(),
          ),
      ],
    );
  }
}

// ── Tiny pulsing dot shown when a face is detected ────────────────────────────

class _FaceTrackDot extends StatefulWidget {
  @override
  State<_FaceTrackDot> createState() => _FaceTrackDotState();
}

class _FaceTrackDotState extends State<_FaceTrackDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Opacity(
        opacity: 0.4 + 0.6 * _pulse.value,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF00FF88),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'FACE',
              style: TextStyle(
                color: Color(0xFF00FF88),
                fontSize: 8,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'emotion_controller.dart';
import 'face_painter.dart';

/// High-level face renderer that composes eyes and mouth
class FaceRenderer extends StatelessWidget {
  final EmotionController emotionController;

  const FaceRenderer({super.key, required this.emotionController});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: emotionController,
      builder: (context, _) {
        return SizedBox.expand(
          child: CustomPaint(
            painter: FacePainter(controller: emotionController),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

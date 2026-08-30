import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../robot/emotion.dart';
import 'emotion_controller.dart';

/// CustomPainter that renders the robot face directly on canvas
/// Produces the minimal, clean robot face aesthetic matching the reference image
class FacePainter extends CustomPainter {
  final EmotionController controller;

  FacePainter({required this.controller});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Face center with subtle bounce
    final faceCenter = Offset(cx, cy + controller.bounceY);

    // Draw background (pure black)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    _drawFace(canvas, faceCenter, size);
  }

  void _drawFace(Canvas canvas, Offset center, Size size) {
    final params = controller.params;

    // Eye dimensions — proportional to screen
    final baseEyeWidth = size.width * 0.085;
    final baseEyeHeight = size.height * 0.28;

    final eyeW = baseEyeWidth * params.eyeScaleX;
    final eyeH = baseEyeHeight * params.eyeScaleY;

    // Eye spacing
    final eyeSpacing = size.width * 0.185;

    // idleEyeX/Y already contain idle sway + face tracking + look command
    final totalOffsetX = controller.idleEyeX;
    final totalOffsetY = controller.idleEyeY + params.eyeOffsetY;

    // Eye positions
    final leftEyePos = Offset(
      center.dx - eyeSpacing + totalOffsetX,
      center.dy - size.height * 0.03 + totalOffsetY,
    );
    final rightEyePos = Offset(
      center.dx + eyeSpacing + totalOffsetX,
      center.dy - size.height * 0.03 + totalOffsetY,
    );

    // Draw glow if applicable (love, excited)
    if (params.enableGlow && params.glowIntensity > 0) {
      _drawEyeGlow(canvas, leftEyePos, eyeW, eyeH, params.glowIntensity);
      _drawEyeGlow(canvas, rightEyePos, eyeW, eyeH, params.glowIntensity);
    }

    // Draw eyes
    _drawEye(canvas, leftEyePos, eyeW, eyeH, params, isLeft: true);
    _drawEye(canvas, rightEyePos, eyeW, eyeH, params, isLeft: false);

    // Mouth position
    final mouthPos = Offset(
      center.dx,
      center.dy + size.height * 0.26 + controller.idleEyeY * 0.3,
    );
    final mouthWidth = size.width * 0.14 * params.mouthScale;

    // Talking modifies mouth
    final talkOpen = controller.talkMouthOpen;
    final mouthH = size.height * 0.025;

    _drawMouth(canvas, mouthPos, mouthWidth, mouthH, params.mouthShape,
        talkOpen, size);
  }

  void _drawEye(
      Canvas canvas, Offset center, double w, double h, EmotionParams params,
      {required bool isLeft}) {
    final blink = controller.blinkProgress;
    final squint = params.eyeSquint;

    // Effective height after blinking and squinting
    final effectiveH = h * (1.0 - blink) * (1.0 - squint * 0.8);

    if (effectiveH <= 0) return;

    // The eye is a rounded rectangle (vertical oval shape)
    final eyeRect =
        Rect.fromCenter(center: center, width: w, height: effectiveH);
    final radius = w * 0.5; // Fully rounded sides

    // Main white eye
    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Soft shadow/glow behind eye for depth
    final shadowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final shadowRect = Rect.fromCenter(
      center: center,
      width: w + 6,
      height: effectiveH + 6,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, Radius.circular(radius + 3)),
      shadowPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(eyeRect, Radius.circular(radius)),
      eyePaint,
    );

    // When thinking or confused, draw a small pupil offset
    if (params.mouthShape == MouthShape.confused ||
        params.mouthShape == MouthShape.smirk) {
      _drawThinkingIndicator(canvas, center, w, effectiveH, isLeft);
    }

    // Squint top clip for angry/sleepy - draw dark overlay on top portion
    if (squint > 0.1) {
      _drawSquintOverlay(canvas, center, w, effectiveH, squint);
    }
  }

  void _drawSquintOverlay(
    Canvas canvas,
    Offset center,
    double w,
    double h,
    double squint,
  ) {
    final cutHeight = h * squint * 0.8;
    final overlayRect = Rect.fromLTWH(
      center.dx - w * 0.6,
      center.dy - h / 2,
      w * 1.2,
      cutHeight,
    );

    canvas.drawRect(overlayRect, Paint()..color = Colors.black);
  }

  void _drawThinkingIndicator(
    Canvas canvas,
    Offset center,
    double w,
    double h,
    bool isLeft,
  ) {
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    // Subtle pupil shift for thinking
    final xShift = isLeft
        ? math.sin(time * 0.8) * w * 0.15
        : math.sin(time * 0.8 + 0.5) * w * 0.15;

    final pupilPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + xShift, center.dy + h * 0.1),
        width: w * 0.3,
        height: h * 0.2,
      ),
      pupilPaint,
    );
  }

  void _drawEyeGlow(
    Canvas canvas,
    Offset center,
    double w,
    double h,
    double intensity,
  ) {
    final glowPaint = Paint()
      ..color = const Color(0xFFFFCCEE).withValues(alpha: intensity * 0.15)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * intensity);

    canvas.drawOval(
      Rect.fromCenter(center: center, width: w * 2.5, height: h * 1.5),
      glowPaint,
    );
  }

  void _drawMouth(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    MouthShape shape,
    double talkOpen,
    Size screenSize,
  ) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = screenSize.height * 0.012
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    switch (shape) {
      case MouthShape.neutral:
        _drawNeutralMouth(canvas, center, width, paint, talkOpen);
        break;
      case MouthShape.smile:
        _drawSmileMouth(canvas, center, width, height, paint, 0.3);
        break;
      case MouthShape.happy:
        _drawSmileMouth(canvas, center, width, height, paint, 0.5);
        break;
      case MouthShape.bigSmile:
        _drawSmileMouth(canvas, center, width, height, paint, 0.8);
        break;
      case MouthShape.talking:
        _drawTalkingMouth(canvas, center, width, height, paint, talkOpen);
        break;
      case MouthShape.surprised:
        _drawSurprisedMouth(canvas, center, width * 0.5, height * 2, paint);
        break;
      case MouthShape.sad:
        _drawSadMouth(canvas, center, width, height, paint);
        break;
      case MouthShape.confused:
        _drawConfusedMouth(canvas, center, width, height, paint);
        break;
      case MouthShape.sleepy:
        _drawSleepyMouth(canvas, center, width, height, paint);
        break;
      case MouthShape.love:
        _drawLoveMouth(canvas, center, width, height, paint);
        break;
      case MouthShape.frown:
        _drawFrownMouth(canvas, center, width, height, paint);
        break;
      case MouthShape.smirk:
        _drawSmirkMouth(canvas, center, width, height, paint);
        break;
    }
  }

  void _drawNeutralMouth(
    Canvas canvas,
    Offset center,
    double width,
    Paint paint,
    double talkOpen,
  ) {
    if (talkOpen > 0.1) {
      // While talking with neutral expression
      _drawTalkingMouth(
        canvas,
        center,
        width,
        paint.strokeWidth * 1.5,
        paint,
        talkOpen,
      );
      return;
    }

    // Simple horizontal line
    canvas.drawLine(
      Offset(center.dx - width / 2, center.dy),
      Offset(center.dx + width / 2, center.dy),
      paint,
    );
  }

  void _drawSmileMouth(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint paint,
    double curvature,
  ) {
    final path = Path();
    final controlY = center.dy + width * curvature;

    path.moveTo(center.dx - width / 2, center.dy);
    path.quadraticBezierTo(
      center.dx,
      controlY,
      center.dx + width / 2,
      center.dy,
    );

    canvas.drawPath(path, paint);
  }

  void _drawSadMouth(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint paint,
  ) {
    final path = Path();
    final controlY = center.dy - width * 0.3;

    path.moveTo(center.dx - width / 2, center.dy);
    path.quadraticBezierTo(
      center.dx,
      controlY,
      center.dx + width / 2,
      center.dy,
    );

    canvas.drawPath(path, paint);
  }

  void _drawFrownMouth(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint paint,
  ) {
    final path = Path();
    final controlY = center.dy - width * 0.25;
    final narrowWidth = width * 0.8;

    path.moveTo(center.dx - narrowWidth / 2, center.dy);
    path.quadraticBezierTo(
      center.dx,
      controlY,
      center.dx + narrowWidth / 2,
      center.dy,
    );

    canvas.drawPath(path, paint);
  }

  void _drawTalkingMouth(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint paint,
    double openAmount,
  ) {
    if (openAmount < 0.05) {
      // Closed line
      canvas.drawLine(
        Offset(center.dx - width / 2, center.dy),
        Offset(center.dx + width / 2, center.dy),
        paint,
      );
      return;
    }

    // Draw open mouth as oval
    final mouthHeight = height + openAmount * 20;
    final fillPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: width * (0.6 + openAmount * 0.4),
        height: mouthHeight,
      ),
      Radius.circular(mouthHeight / 2),
    );

    // White border
    canvas.drawRRect(rrect, paint..style = PaintingStyle.stroke);
    canvas.drawRRect(rrect, fillPaint);

    // Restore stroke style
    paint.style = PaintingStyle.stroke;
  }

  void _drawSurprisedMouth(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint paint,
  ) {
    // Small open oval
    canvas.drawOval(
      Rect.fromCenter(center: center, width: width, height: height),
      paint,
    );
  }

  void _drawConfusedMouth(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint paint,
  ) {
    // Wavy/tilted line
    final path = Path();
    path.moveTo(center.dx - width / 2, center.dy + 3);
    path.cubicTo(
      center.dx - width / 4,
      center.dy - 4,
      center.dx + width / 4,
      center.dy + 6,
      center.dx + width / 2,
      center.dy - 2,
    );
    canvas.drawPath(path, paint);
  }

  void _drawSleepyMouth(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint paint,
  ) {
    // Slightly open, relaxed
    final narrowWidth = width * 0.7;
    canvas.drawLine(
      Offset(center.dx - narrowWidth / 2, center.dy),
      Offset(center.dx + narrowWidth / 2, center.dy),
      paint..strokeWidth = paint.strokeWidth * 0.8,
    );
  }

  void _drawLoveMouth(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint paint,
  ) {
    // Small smile with a tiny heart shape implied
    _drawSmileMouth(canvas, center, width * 0.8, height, paint, 0.4);
  }

  void _drawSmirkMouth(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint paint,
  ) {
    // Asymmetric line - one side slightly higher
    final path = Path();
    path.moveTo(center.dx - width / 2, center.dy + 2);
    path.quadraticBezierTo(
      center.dx + width * 0.1,
      center.dy,
      center.dx + width / 2,
      center.dy - 6,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) => true;
}

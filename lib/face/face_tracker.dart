import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Advanced AI Person & Face Tracker engine.
///
/// Implements:
/// 1. Adaptive Dual-Alpha EMA Filtering (fast on big moves, calm on micro moves)
/// 2. Predictive Velocity Momentum (eyes anticipate person movement)
/// 3. Person Persistence Coasting (holds tracking for ~3s when person turns around)
/// 4. Extended Distance Detection (minFaceSize = 0.05 for distant tracking)
class FaceTracker {
  // ── Public stream ──────────────────────────────────────────
  final _positionController = StreamController<FacePosition>.broadcast();
  Stream<FacePosition> get positionStream => _positionController.stream;

  // ── Private state ──────────────────────────────────────────
  CameraController? _camera;
  FaceDetector? _detector;
  bool _processing = false;
  bool _running = false;

  // Filtered & predicted position states
  double _filteredX = 0.0;
  double _filteredY = 0.0;
  double _velocityX = 0.0;
  double _velocityY = 0.0;
  double _lastRawX = 0.0;
  double _lastRawY = 0.0;
  DateTime? _lastFrameTime;
  bool _hasFirstSample = false;

  // Person Memory Coasting state (tracks person even when face turns/drops)
  int _missedFrameCount = 0;
  static const int _maxMissedFramesBeforeReset = 60; // ~3.5 seconds persistence

  // Sensitivity multiplier for tablet display
  static const double sensitivity = 1.35;

  // ── Lifecycle ──────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('[FaceTracker] No cameras found on device');
        return;
      }

      // Prefer front camera for person tracking
      final camDesc = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      debugPrint('[FaceTracker] Selected camera: ${camDesc.name} (${camDesc.lensDirection.name}), sensorOrientation: ${camDesc.sensorOrientation}°');

      _camera = CameraController(
        camDesc,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _camera!.initialize();

      // Configure ML Kit for extended distance tracking (minFaceSize = 0.05)
      _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: false,
          enableClassification: false,
          enableTracking: true,
          minFaceSize: 0.05,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

      _running = true;
      _hasFirstSample = false;
      _missedFrameCount = 0;
      _velocityX = 0.0;
      _velocityY = 0.0;

      await _camera!.startImageStream(_onFrame);
      debugPrint('[FaceTracker] AI Person Tracking started successfully');
    } catch (e, st) {
      debugPrint('[FaceTracker] Start error: $e\n$st');
    }
  }

  Future<void> stop() async {
    _running = false;
    try {
      await _camera?.stopImageStream();
    } catch (_) {}
    await _camera?.dispose();
    _camera = null;
    _detector?.close();
    _detector = null;
    debugPrint('[FaceTracker] Stopped');
  }

  void dispose() {
    stop();
    _positionController.close();
  }

  // ── Frame processing ───────────────────────────────────────

  void _onFrame(CameraImage image) {
    if (_processing || !_running || _detector == null) return;
    _processing = true;

    _processFrame(image).then((_) {
      _processing = false;
    }).catchError((e) {
      debugPrint('[FaceTracker] Frame processing error: $e');
      _processing = false;
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;

      final now = DateTime.now();
      final dt = _lastFrameTime != null
          ? now.difference(_lastFrameTime!).inMilliseconds / 1000.0
          : 0.05;
      _lastFrameTime = now;

      final faces = await _detector!.processImage(inputImage);

      if (faces.isEmpty) {
        _missedFrameCount++;

        // Person Memory Coasting: slowly decay velocity and maintain target position
        if (_missedFrameCount < _maxMissedFramesBeforeReset) {
          _velocityX *= 0.92;
          _velocityY *= 0.92;
          _filteredX = (_filteredX + _velocityX * dt).clamp(-1.0, 1.0);
          _filteredY = (_filteredY + _velocityY * dt).clamp(-1.0, 1.0);
          _positionController.add(FacePosition(_filteredX, _filteredY));
        } else {
          // Person has left room after ~3.5s of no detection — return to center
          _filteredX = 0.0;
          _filteredY = 0.0;
          _velocityX = 0.0;
          _velocityY = 0.0;
          _hasFirstSample = false;
          _positionController.add(const FacePosition(0, 0));
        }
        return;
      }

      // Person detected — reset missed frame counter
      _missedFrameCount = 0;

      // Select primary person (largest face box)
      final face = faces.reduce((a, b) =>
          a.boundingBox.width * a.boundingBox.height >
          b.boundingBox.width * b.boundingBox.height
              ? a
              : b);

      // Determine dimensions based on sensor rotation
      final rotation = inputImage.metadata?.rotation ?? InputImageRotation.rotation0deg;
      final isRotated = rotation == InputImageRotation.rotation90deg ||
          rotation == InputImageRotation.rotation270deg;

      final frameW = isRotated ? image.height.toDouble() : image.width.toDouble();
      final frameH = isRotated ? image.width.toDouble() : image.height.toDouble();

      final faceCx = face.boundingBox.center.dx;
      final faceCy = face.boundingBox.center.dy;

      // Raw normalised coordinates [-1, 1] (mirrored horizontally for front cam)
      final rawX = -((faceCx / frameW) * 2.0 - 1.0) * sensitivity;
      final rawY =  ((faceCy / frameH) * 2.0 - 1.0) * sensitivity;

      final targetX = rawX.clamp(-1.0, 1.0);
      final targetY = rawY.clamp(-1.0, 1.0);

      if (!_hasFirstSample) {
        _filteredX = targetX;
        _filteredY = targetY;
        _lastRawX = targetX;
        _lastRawY = targetY;
        _velocityX = 0.0;
        _velocityY = 0.0;
        _hasFirstSample = true;
      } else {
        // Calculate instantaneous velocity
        final instVx = (targetX - _lastRawX) / (dt > 0.001 ? dt : 0.05);
        final instVy = (targetY - _lastRawY) / (dt > 0.001 ? dt : 0.05);
        _lastRawX = targetX;
        _lastRawY = targetY;

        // Smooth velocity
        _velocityX = _velocityX + 0.3 * (instVx - _velocityX);
        _velocityY = _velocityY + 0.3 * (instVy - _velocityY);

        // Predictive target with momentum prediction
        final predictedX = (targetX + _velocityX * 0.08).clamp(-1.0, 1.0);
        final predictedY = (targetY + _velocityY * 0.08).clamp(-1.0, 1.0);

        // Adaptive Dual-Alpha Filter:
        // High alpha (fast follow) on large movements, low alpha (calm stability) on small movements
        final moveDist = math.sqrt((predictedX - _filteredX) * (predictedX - _filteredX) +
                                   (predictedY - _filteredY) * (predictedY - _filteredY));
        final alpha = (moveDist > 0.15) ? 0.35 : (moveDist > 0.05 ? 0.22 : 0.12);

        _filteredX = _filteredX + alpha * (predictedX - _filteredX);
        _filteredY = _filteredY + alpha * (predictedY - _filteredY);
      }

      _positionController.add(FacePosition(_filteredX, _filteredY));
    } catch (e) {
      debugPrint('[FaceTracker] AI Tracking error: $e');
    }
  }

  // ── ML Kit InputImage conversion ──────────────────────────

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        (Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888);

    final rotation = _sensorRotation(camera.description.sensorOrientation);
    final bytes = _concatenatePlanes(image.planes);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    if (planes.length == 1) {
      return planes.first.bytes;
    }

    final totalBytes = planes.fold<int>(0, (sum, p) => sum + p.bytes.lengthInBytes);
    final allBytes = Uint8List(totalBytes);
    int offset = 0;
    for (final plane in planes) {
      allBytes.setRange(offset, offset + plane.bytes.lengthInBytes, plane.bytes);
      offset += plane.bytes.lengthInBytes;
    }
    return allBytes;
  }

  InputImageRotation _sensorRotation(int sensorDegrees) {
    switch (sensorDegrees) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }
}

// ── Public Value Object ──────────────────────────────────────────────────────

class FacePosition {
  final double x; // -1 = person left, +1 = person right
  final double y; // -1 = person top,  +1 = person bottom

  const FacePosition(this.x, this.y);
}

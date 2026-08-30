import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceTrackingController extends ChangeNotifier {
  CameraController? cameraController;
  late final FaceDetector _faceDetector;

  bool isInitialized = false;
  bool faceDetected = false;
  String debugStatus = 'Starting camera';

  double faceX = 0.0;
  double faceY = 0.0;

  bool _isProcessing = false;
  bool _streaming = false;
  DateTime _lastProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);

  // EMA (Exponential Moving Average) filter values
  double _filteredX = 0.0;
  double _filteredY = 0.0;
  bool _hasFirstSample = false;
  int _missedFrameCount = 0;

  static const Duration _processingInterval = Duration(milliseconds: 50);
  static const double _emaAlpha = 0.22;

  FaceTrackingController() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: false,
        enableContours: false,
        enableClassification: false,
        enableTracking: true,
        minFaceSize: 0.08,
      ),
    );
  }

  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        debugStatus = 'No camera found';
        notifyListeners();
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await cameraController!.initialize();

      isInitialized = true;
      debugStatus = 'Searching for face';
      notifyListeners();

      _streaming = true;
      _hasFirstSample = false;
      _missedFrameCount = 0;
      await cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      debugStatus = 'Init error: $e';
      notifyListeners();
      debugPrint('[FaceTrackingController] Init error: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;

    final now = DateTime.now();
    if (now.difference(_lastProcessedAt) < _processingInterval) return;
    _lastProcessedAt = now;

    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image);

      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        _missedFrameCount++;
        if (_missedFrameCount >= 15) {
          faceDetected = false;
          debugStatus = 'Searching for face';
          faceX = 0.0;
          faceY = 0.0;
          _hasFirstSample = false;
          notifyListeners();
        }
      } else {
        _missedFrameCount = 0;
        faceDetected = true;

        final face = _largestFace(faces);

        final rotation = inputImage.metadata?.rotation ?? InputImageRotation.rotation0deg;
        final isRotated = rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg;

        final frameW = isRotated ? image.height.toDouble() : image.width.toDouble();
        final frameH = isRotated ? image.width.toDouble() : image.height.toDouble();

        final centerX = face.boundingBox.center.dx;
        final centerY = face.boundingBox.center.dy;

        // Convert to [-1, +1] range
        final rawX = -((centerX / frameW) * 2.0 - 1.0);
        final rawY =  ((centerY / frameH) * 2.0 - 1.0);

        final clampedX = rawX.clamp(-1.0, 1.0);
        final clampedY = rawY.clamp(-1.0, 1.0);

        if (!_hasFirstSample) {
          _filteredX = clampedX;
          _filteredY = clampedY;
          _hasFirstSample = true;
        } else {
          _filteredX = _filteredX + _emaAlpha * (clampedX - _filteredX);
          _filteredY = _filteredY + _emaAlpha * (clampedY - _filteredY);
        }

        faceX = _filteredX;
        faceY = _filteredY;

        debugStatus =
            'Face x=${faceX.toStringAsFixed(2)} y=${faceY.toStringAsFixed(2)}';

        notifyListeners();
      }
    } catch (e) {
      debugStatus = 'Tracking error: $e';
      notifyListeners();
      debugPrint('[FaceTrackingController] Tracking error: $e');
    }

    _isProcessing = false;
  }

  Face _largestFace(List<Face> faces) {
    Face largest = faces.first;
    double largestArea = largest.boundingBox.width * largest.boundingBox.height;

    for (final face in faces.skip(1)) {
      final area = face.boundingBox.width * face.boundingBox.height;
      if (area > largestArea) {
        largest = face;
        largestArea = area;
      }
    }

    return largest;
  }

  InputImage? _convertCameraImage(CameraImage image) {
    final controller = cameraController;
    if (controller == null) return null;

    final camera = controller.description;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        (Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888);

    final rotation = _sensorRotation(camera.sensorOrientation);
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

  Future<void> disposeTracker() async {
    if (_streaming) {
      try {
        await cameraController?.stopImageStream();
      } catch (e) {
        debugPrint('Face tracking stream stop error: $e');
      }
      _streaming = false;
    }

    await cameraController?.dispose();
    _faceDetector.close();
  }
}

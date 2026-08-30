import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../robot/emotion.dart';

/// Manages all animation controllers for the robot face.
/// Now includes real-time face-tracking support: call [setFaceTarget]
/// with normalised [-1, 1] coordinates from FaceTracker.
class EmotionController extends ChangeNotifier {
  final TickerProvider vsync;

  // Current state
  RobotEmotion _currentEmotion = RobotEmotion.neutral;
  RobotEmotion _targetEmotion  = RobotEmotion.neutral;
  EyeDirection _eyeDirection   = EyeDirection.center;
  bool _isTalking = false;

  // Interpolated params (current rendered values)
  EmotionParams _rendered = EmotionDefinitions.get(RobotEmotion.neutral);
  EmotionParams _from     = EmotionDefinitions.get(RobotEmotion.neutral);
  EmotionParams _to       = EmotionDefinitions.get(RobotEmotion.neutral);

  // Animation controllers
  late AnimationController _transitionController;
  late AnimationController _idleController;
  late AnimationController _blinkController;
  late AnimationController _talkController;
  late AnimationController _bounceController;
  late AnimationController _lookController;

  // ── Idle sway ─────────────────────────────────────────────
  double _idleEyeX = 0.0;
  double _idleEyeY = 0.0;
  double _breathe  = 0.0;

  // ── Blink ─────────────────────────────────────────────────
  bool   _isBlinking     = false;
  double _blinkProgress  = 0.0; // 0 = open, 1 = closed

  // ── Talk ──────────────────────────────────────────────────
  double _talkMouthScale = 1.0;
  double _talkMouthOpen  = 0.0;

  // ── Look command offset ───────────────────────────────────
  double _lookOffsetX  = 0.0;
  double _lookOffsetY  = 0.0;
  double _lookTargetX  = 0.0;
  double _lookTargetY  = 0.0;

  // ── Face tracking (camera-driven) ─────────────────────────
  // Target set by FaceTracker (pixel units, max ±14 / ±8)
  double _faceTargetX  = 0.0;
  double _faceTargetY  = 0.0;
  // Current smoothed position (lerped toward target every frame)
  double _faceCurrentX = 0.0;
  double _faceCurrentY = 0.0;
  bool   _faceTracking = false;
  // Smoothing: 0 = instant, 1 = never moves. 0.18 → ~18% per frame
  static const double _faceSmooth = 0.18;

  // ── Bounce ────────────────────────────────────────────────
  double _bounceY = 0.0;

  // Blink schedule
  DateTime _nextBlink = DateTime.now();
  final _rng = math.Random();

  // Ticker
  Ticker? _idleTicker;
  Duration _lastIdleTime = Duration.zero;

  EmotionController({required this.vsync}) {
    _initControllers();
    _startIdleLoop();
  }

  // ── Getters used by FacePainter ───────────────────────────

  EmotionParams get params => _rendered;

  /// Total horizontal eye offset = idle sway + face tracking + look command
  double get idleEyeX => _idleEyeX + _faceCurrentX + _lookOffsetX;

  /// Total vertical eye offset = idle sway + face tracking + look command
  double get idleEyeY => _idleEyeY + _faceCurrentY + _lookOffsetY;

  double get breathe         => _breathe;
  double get blinkProgress   => _blinkProgress;
  double get talkMouthScale  => _talkMouthScale;
  double get talkMouthOpen   => _talkMouthOpen;

  // lookOffset is now merged into idleEyeX/Y so keep these zero for painter
  double get lookOffsetX => 0.0;
  double get lookOffsetY => 0.0;

  double get bounceY => _bounceY;

  EyeDirection   get eyeDirection   => _eyeDirection;
  bool           get isTalking      => _isTalking;
  RobotEmotion   get currentEmotion => _currentEmotion;
  bool           get faceTracking   => _faceTracking;

  // ── Init ──────────────────────────────────────────────────

  void _initControllers() {
    _transitionController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 600),
    );
    _idleController = AnimationController(
      vsync: vsync,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _blinkController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 150),
    );
    _talkController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 200),
    );
    _bounceController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 800),
    );
    _lookController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 400),
    );

    _transitionController.addListener(_onTransitionUpdate);
    _idleController.addListener(_onIdleUpdate);
    _blinkController.addListener(_onBlinkUpdate);
    _talkController.addListener(_onTalkUpdate);
    _bounceController.addListener(_onBounceUpdate);
    _lookController.addListener(_onLookUpdate);
  }

  void _startIdleLoop() {
    _idleTicker = vsync.createTicker(_update);
    _idleTicker!.start();
  }

  // ── Per-frame update ──────────────────────────────────────

  void _update(Duration elapsed) {
    final dt    = elapsed - _lastIdleTime;
    _lastIdleTime = elapsed;
    final dtSec = dt.inMicroseconds / 1000000.0;

    _updateBlink(dtSec);
    _updateIdleMovement(dtSec);
    _updateTalking(dtSec);
    _updateFaceTracking();

    notifyListeners();
  }

  // ── Face tracking smooth follow ───────────────────────────

  void _updateFaceTracking() {
    final dx = _faceTargetX - _faceCurrentX;
    final dy = _faceTargetY - _faceCurrentY;

    // Organic spring-dampened follow
    _faceCurrentX += dx * 0.18;
    _faceCurrentY += dy * 0.18;
  }

  // ── Blink ─────────────────────────────────────────────────

  void _updateBlink(double dt) {
    if (_isBlinking) return;
    if (DateTime.now().isAfter(_nextBlink)) {
      _triggerBlink();
      _scheduleNextBlink();
    }
  }

  void _scheduleNextBlink() {
    final base      = EmotionDefinitions.get(_targetEmotion).blinkIntervalSeconds;
    final variation = base * 0.3;
    final interval  = base + (_rng.nextDouble() * variation * 2 - variation);
    _nextBlink = DateTime.now()
        .add(Duration(milliseconds: (interval * 1000).round()));
  }

  Future<void> _triggerBlink({bool doubleBlink = false}) async {
    if (_isBlinking) return;
    _isBlinking = true;
    await _animateBlink(0.0, 1.0, const Duration(milliseconds: 80));
    await _animateBlink(1.0, 0.0, const Duration(milliseconds: 100));
    if (doubleBlink) {
      await Future.delayed(const Duration(milliseconds: 80));
      await _animateBlink(0.0, 1.0, const Duration(milliseconds: 80));
      await _animateBlink(1.0, 0.0, const Duration(milliseconds: 100));
    }
    _isBlinking = false;
  }

  Future<void> _animateBlink(double from, double to, Duration dur) async {
    const steps = 10;
    final stepMs = dur.inMilliseconds ~/ steps;
    for (int i = 0; i <= steps; i++) {
      _blinkProgress = from + (to - from) * (i / steps);
      await Future.delayed(Duration(milliseconds: stepMs));
    }
  }

  // ── Idle sway (Lissajous) ─────────────────────────────────

  void _updateIdleMovement(double dt) {
    final p = EmotionDefinitions.get(_targetEmotion);
    if (!p.enableIdle) {
      _idleEyeX *= 0.95;
      _idleEyeY *= 0.95;
      return;
    }
    final intensity = p.idleIntensity * 3.0;
    final t = _lastIdleTime.inMilliseconds / 1000.0;
    _idleEyeX = math.sin(t * 0.3) * intensity * 0.5
              + math.sin(t * 0.7) * intensity * 0.3;
    _idleEyeY = math.cos(t * 0.4) * intensity * 0.4
              + math.sin(t * 0.5) * intensity * 0.2;
    _breathe  = math.sin(t * 0.8) * 0.015;
  }

  // ── Talking mouth animation ───────────────────────────────

  void _updateTalking(double dt) {
    if (!_isTalking) {
      _talkMouthOpen  *= 0.9;
      _talkMouthScale  = 1.0 + _talkMouthOpen * 0.2;
      return;
    }
    final t = _lastIdleTime.inMilliseconds / 1000.0;
    _talkMouthOpen = (math.sin(t * 8.0)  * 0.5 +
                      math.sin(t * 13.0) * 0.3 +
                      math.sin(t * 5.0)  * 0.2) * 0.6 + 0.4;
    _talkMouthOpen  = _talkMouthOpen.clamp(0.0, 1.0);
    _talkMouthScale = 1.0 + _talkMouthOpen * 0.3;
  }

  // ── Controller listeners ──────────────────────────────────

  void _onTransitionUpdate() {
    final t = _curveTransition(_transitionController.value);
    _rendered = _interpolateParams(_from, _to, t);
  }

  double _curveTransition(double t) => t * t * (3 - 2 * t);

  EmotionParams _interpolateParams(EmotionParams a, EmotionParams b, double t) {
    return EmotionParams(
      eyeScaleX:           _lerp(a.eyeScaleX,           b.eyeScaleX,           t),
      eyeScaleY:           _lerp(a.eyeScaleY,           b.eyeScaleY,           t),
      eyeOffsetY:          _lerp(a.eyeOffsetY,          b.eyeOffsetY,          t),
      eyeSquint:           _lerp(a.eyeSquint,           b.eyeSquint,           t),
      eyeSurprise:         _lerp(a.eyeSurprise,         b.eyeSurprise,         t),
      mouthShape:          t < 0.5 ? a.mouthShape : b.mouthShape,
      mouthScale:          _lerp(a.mouthScale,          b.mouthScale,          t),
      enableBlink:         b.enableBlink,
      blinkIntervalSeconds:_lerp(a.blinkIntervalSeconds,b.blinkIntervalSeconds,t),
      animationSpeed:      _lerp(a.animationSpeed,      b.animationSpeed,      t),
      enableIdle:          b.enableIdle,
      idleIntensity:       _lerp(a.idleIntensity,       b.idleIntensity,       t),
      enableBounce:        b.enableBounce,
      bounceIntensity:     _lerp(a.bounceIntensity,     b.bounceIntensity,     t),
      enableGlow:          b.enableGlow,
      glowIntensity:       _lerp(a.glowIntensity,       b.glowIntensity,       t),
    );
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _onIdleUpdate()   {}
  void _onBlinkUpdate()  {}
  void _onTalkUpdate()   {}

  void _onBounceUpdate() {
    final t = _bounceController.value;
    final p = EmotionDefinitions.get(_targetEmotion);
    if (p.enableBounce) {
      _bounceY = math.sin(t * math.pi * 2) * p.bounceIntensity * 4.0;
    }
  }

  void _onLookUpdate() {
    final t = CurvedAnimation(
      parent: _lookController,
      curve: Curves.easeInOut,
    ).value;
    _lookOffsetX = _lookTargetX * t;
    _lookOffsetY = _lookTargetY * t;
  }

  // ── Public API ────────────────────────────────────────────

  /// Called from FaceTracker with normalised face position [-1, 1].
  /// Eyes smoothly follow in real time.
  void setFaceTarget(double normX, double normY) {
    // Map ±1 → ±pixels (max travel for tablet screen)
    const maxX = 45.0;
    const maxY = 25.0;
    _faceTargetX = normX.clamp(-1.0, 1.0) * maxX;
    _faceTargetY = normY.clamp(-1.0, 1.0) * maxY;
    _faceTracking = true;
  }

  /// Called when no face is detected — eyes drift back to centre.
  void clearFaceTarget() {
    _faceTargetX  = 0.0;
    _faceTargetY  = 0.0;
    _faceTracking = false;
  }

  void setEmotion(
    RobotEmotion emotion, {
    EyeDirection eyeDirection = EyeDirection.center,
    bool isTalking            = false,
    bool forceBlink           = false,
  }) {
    if (forceBlink) _triggerBlink();

    if (_eyeDirection != eyeDirection) {
      _eyeDirection = eyeDirection;
      _updateLookTarget();
    }

    _isTalking = isTalking;

    if (_targetEmotion == emotion) return;

    _targetEmotion = emotion;
    _from = EmotionParams(
      eyeScaleX:            _rendered.eyeScaleX,
      eyeScaleY:            _rendered.eyeScaleY,
      eyeOffsetY:           _rendered.eyeOffsetY,
      eyeSquint:            _rendered.eyeSquint,
      eyeSurprise:          _rendered.eyeSurprise,
      mouthShape:           _rendered.mouthShape,
      mouthScale:           _rendered.mouthScale,
      enableBlink:          _rendered.enableBlink,
      blinkIntervalSeconds: _rendered.blinkIntervalSeconds,
      animationSpeed:       _rendered.animationSpeed,
      enableIdle:           _rendered.enableIdle,
      idleIntensity:        _rendered.idleIntensity,
      enableBounce:         _rendered.enableBounce,
      bounceIntensity:      _rendered.bounceIntensity,
      enableGlow:           _rendered.enableGlow,
      glowIntensity:        _rendered.glowIntensity,
    );
    _to = EmotionDefinitions.get(emotion);

    final speed = _to.animationSpeed;
    _transitionController.duration =
        Duration(milliseconds: (600 / speed).round().clamp(300, 1200));
    _transitionController.forward(from: 0.0);

    if (_to.enableBounce && _to.bounceIntensity > 0) {
      _bounceController.repeat();
    } else {
      _bounceController.stop();
      _bounceY = 0.0;
    }

    _currentEmotion = emotion;
    _scheduleNextBlink();
  }

  void _updateLookTarget() {
    switch (_eyeDirection) {
      case EyeDirection.left:
        _lookTargetX = -12.0; _lookTargetY = 0.0;
      case EyeDirection.right:
        _lookTargetX =  12.0; _lookTargetY = 0.0;
      case EyeDirection.up:
        _lookTargetX = 0.0; _lookTargetY = -8.0;
      case EyeDirection.down:
        _lookTargetX = 0.0; _lookTargetY =  8.0;
      case EyeDirection.center:
        _lookTargetX = 0.0; _lookTargetY =  0.0;
    }
    _lookController.forward(from: 0.0);

    if (_eyeDirection != EyeDirection.center) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        _eyeDirection = EyeDirection.center;
        _lookTargetX  = 0.0;
        _lookTargetY  = 0.0;
        _lookController.forward(from: 0.0);
      });
    }
  }

  @override
  void dispose() {
    _idleTicker?.dispose();
    _transitionController.dispose();
    _idleController.dispose();
    _blinkController.dispose();
    _talkController.dispose();
    _bounceController.dispose();
    _lookController.dispose();
    super.dispose();
  }
}

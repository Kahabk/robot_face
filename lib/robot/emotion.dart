/// All supported robot emotions
enum RobotEmotion {
  neutral,
  happy,
  excited,
  sad,
  angry,
  confused,
  surprised,
  sleepy,
  love,
  thinking,
  talking,
  listening,
  error,
  sleep,
}

/// All supported robot states (higher-level than emotions)
enum RobotState {
  idle,
  talking,
  listening,
  thinking,
  sleeping,
  error,
}

/// Eye direction for look commands
enum EyeDirection {
  center,
  left,
  right,
  up,
  down,
}

/// Parameters defining how an emotion looks and animates
class EmotionParams {
  final double eyeScaleX;
  final double eyeScaleY;
  final double eyeOffsetY;
  final double eyeSquint; // 0 = fully open, 1 = nearly closed
  final double eyeSurprise; // Extra vertical stretch
  final MouthShape mouthShape;
  final double mouthScale;
  final bool enableBlink;
  final double blinkIntervalSeconds;
  final double animationSpeed;
  final bool enableIdle;
  final double idleIntensity;
  final bool enableBounce;
  final double bounceIntensity;
  final bool enableGlow; // subtle eye glow for emotions like love
  final double glowIntensity;

  const EmotionParams({
    this.eyeScaleX = 1.0,
    this.eyeScaleY = 1.0,
    this.eyeOffsetY = 0.0,
    this.eyeSquint = 0.0,
    this.eyeSurprise = 0.0,
    this.mouthShape = MouthShape.neutral,
    this.mouthScale = 1.0,
    this.enableBlink = true,
    this.blinkIntervalSeconds = 4.0,
    this.animationSpeed = 1.0,
    this.enableIdle = true,
    this.idleIntensity = 1.0,
    this.enableBounce = false,
    this.bounceIntensity = 0.0,
    this.enableGlow = false,
    this.glowIntensity = 0.0,
  });
}

enum MouthShape {
  neutral,
  smile,
  happy,
  bigSmile,
  talking,
  surprised,
  sad,
  confused,
  sleepy,
  love,
  frown,
  smirk,
}

/// Static definition of emotion parameters for all emotions
class EmotionDefinitions {
  static const Map<RobotEmotion, EmotionParams> definitions = {
    RobotEmotion.neutral: EmotionParams(
      eyeScaleX: 1.0,
      eyeScaleY: 1.0,
      eyeSquint: 0.0,
      mouthShape: MouthShape.neutral,
      blinkIntervalSeconds: 4.5,
      enableIdle: true,
      idleIntensity: 0.3,
    ),
    RobotEmotion.happy: EmotionParams(
      eyeScaleX: 1.05,
      eyeScaleY: 0.85,
      eyeOffsetY: -4.0,
      eyeSquint: 0.15,
      mouthShape: MouthShape.smile,
      mouthScale: 1.1,
      blinkIntervalSeconds: 3.0,
      enableIdle: true,
      idleIntensity: 0.5,
      enableBounce: true,
      bounceIntensity: 0.4,
      animationSpeed: 1.2,
    ),
    RobotEmotion.excited: EmotionParams(
      eyeScaleX: 1.1,
      eyeScaleY: 1.2,
      eyeOffsetY: -6.0,
      eyeSurprise: 0.2,
      mouthShape: MouthShape.bigSmile,
      mouthScale: 1.3,
      blinkIntervalSeconds: 2.0,
      enableIdle: true,
      idleIntensity: 0.8,
      enableBounce: true,
      bounceIntensity: 0.7,
      animationSpeed: 1.5,
    ),
    RobotEmotion.sad: EmotionParams(
      eyeScaleX: 0.9,
      eyeScaleY: 0.9,
      eyeOffsetY: 4.0,
      eyeSquint: 0.0,
      mouthShape: MouthShape.sad,
      mouthScale: 0.9,
      blinkIntervalSeconds: 6.0,
      enableIdle: true,
      idleIntensity: 0.2,
      animationSpeed: 0.7,
    ),
    RobotEmotion.angry: EmotionParams(
      eyeScaleX: 1.1,
      eyeScaleY: 0.75,
      eyeOffsetY: 2.0,
      eyeSquint: 0.25,
      mouthShape: MouthShape.frown,
      mouthScale: 0.9,
      blinkIntervalSeconds: 8.0,
      enableIdle: false,
      idleIntensity: 0.1,
      animationSpeed: 0.8,
    ),
    RobotEmotion.confused: EmotionParams(
      eyeScaleX: 1.0,
      eyeScaleY: 1.0,
      eyeOffsetY: 0.0,
      mouthShape: MouthShape.confused,
      mouthScale: 1.0,
      blinkIntervalSeconds: 3.5,
      enableIdle: true,
      idleIntensity: 0.6,
      animationSpeed: 0.9,
    ),
    RobotEmotion.surprised: EmotionParams(
      eyeScaleX: 1.05,
      eyeScaleY: 1.4,
      eyeOffsetY: -5.0,
      eyeSurprise: 0.4,
      mouthShape: MouthShape.surprised,
      mouthScale: 1.2,
      blinkIntervalSeconds: 10.0,
      enableIdle: false,
      idleIntensity: 0.0,
      animationSpeed: 1.3,
    ),
    RobotEmotion.sleepy: EmotionParams(
      eyeScaleX: 1.0,
      eyeScaleY: 0.5,
      eyeSquint: 0.5,
      mouthShape: MouthShape.sleepy,
      mouthScale: 0.8,
      blinkIntervalSeconds: 2.5,
      enableIdle: true,
      idleIntensity: 0.1,
      animationSpeed: 0.5,
    ),
    RobotEmotion.love: EmotionParams(
      eyeScaleX: 1.05,
      eyeScaleY: 0.9,
      eyeSquint: 0.1,
      mouthShape: MouthShape.love,
      mouthScale: 1.0,
      blinkIntervalSeconds: 3.0,
      enableIdle: true,
      idleIntensity: 0.4,
      enableBounce: true,
      bounceIntensity: 0.3,
      enableGlow: true,
      glowIntensity: 0.6,
      animationSpeed: 0.9,
    ),
    RobotEmotion.thinking: EmotionParams(
      eyeScaleX: 0.95,
      eyeScaleY: 0.95,
      eyeOffsetY: 0.0,
      mouthShape: MouthShape.smirk,
      mouthScale: 0.8,
      blinkIntervalSeconds: 4.0,
      enableIdle: true,
      idleIntensity: 0.7,
      animationSpeed: 0.8,
    ),
    RobotEmotion.talking: EmotionParams(
      eyeScaleX: 1.0,
      eyeScaleY: 1.0,
      mouthShape: MouthShape.talking,
      mouthScale: 1.0,
      blinkIntervalSeconds: 3.5,
      enableIdle: true,
      idleIntensity: 0.4,
      animationSpeed: 1.1,
    ),
    RobotEmotion.listening: EmotionParams(
      eyeScaleX: 1.0,
      eyeScaleY: 1.05,
      eyeOffsetY: -2.0,
      mouthShape: MouthShape.neutral,
      mouthScale: 0.9,
      blinkIntervalSeconds: 3.0,
      enableIdle: true,
      idleIntensity: 0.5,
      animationSpeed: 0.9,
    ),
    RobotEmotion.error: EmotionParams(
      eyeScaleX: 0.85,
      eyeScaleY: 0.85,
      eyeSquint: 0.1,
      mouthShape: MouthShape.confused,
      mouthScale: 0.9,
      blinkIntervalSeconds: 1.5,
      enableIdle: false,
      idleIntensity: 0.0,
      animationSpeed: 1.0,
    ),
    RobotEmotion.sleep: EmotionParams(
      eyeScaleX: 1.0,
      eyeScaleY: 0.05,
      eyeSquint: 0.95,
      mouthShape: MouthShape.sleepy,
      mouthScale: 0.7,
      blinkIntervalSeconds: 60.0,
      enableIdle: false,
      idleIntensity: 0.0,
      animationSpeed: 0.3,
    ),
  };

  static EmotionParams get(RobotEmotion emotion) {
    return definitions[emotion] ?? const EmotionParams();
  }
}

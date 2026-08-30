import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'robot/robot_controller.dart';
import 'robot/emotion.dart';
import 'face/robot_face.dart';
import 'friend_cam/friend_cam_screen.dart';
import 'settings/device_config.dart';
import 'permission_gate.dart';

void main() async {
  // Catch ALL unhandled exceptions — prevents black screen crashes
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Keep screen awake — non-fatal if device doesn't support it
    try {
      await WakelockPlus.enable();
    } catch (_) {}

    // Force landscape orientation — non-fatal
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (_) {}

    // Immersive fullscreen — non-fatal
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DeviceConfig()),
          ChangeNotifierProvider(
            create: (context) => RobotController(
              config: context.read<DeviceConfig>(),
            ),
          ),
        ],
        child: const RobotFaceApp(),
      ),
    );
  }, (error, stack) {
    // Log errors but never crash the face app
    debugPrint('[App] Unhandled error: $error');
  });
}

class RobotFaceApp extends StatelessWidget {
  const RobotFaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Face',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          surface: Colors.black,
          onSurface: Colors.white,
        ),
      ),
      home: const PermissionGate(
        child: RobotFaceScreen(),
      ),
    );
  }
}

class RobotFaceScreen extends StatefulWidget {
  const RobotFaceScreen({super.key});

  @override
  State<RobotFaceScreen> createState() => _RobotFaceScreenState();
}

class _RobotFaceScreenState extends State<RobotFaceScreen> {
  int _tapCount = 0;
  DateTime? _lastTap;
  bool _devModeVisible = false;
  bool _friendCamVisible = false;

  @override
  void initState() {
    super.initState();
    // Start robot controller after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RobotController>().initialize();
    });
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inMilliseconds > 2000) {
      _tapCount = 0;
    }
    _lastTap = now;
    _tapCount++;

    // 7 rapid taps in top-right corner → developer mode
    if (_tapCount >= 7) {
      setState(() {
        _devModeVisible = !_devModeVisible;
      });
      _tapCount = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Main robot face
            if (_friendCamVisible)
              FriendCamScreen(
                onClose: () => setState(() => _friendCamVisible = false),
              )
            else
              const RobotFace(),

            // Developer mode overlay (hidden by default)
            if (_devModeVisible)
              Positioned(
                top: 0,
                right: 0,
                child: _DevModePanel(
                  onClose: () => setState(() => _devModeVisible = false),
                  onOpenFriendCam: () => setState(() {
                    _friendCamVisible = true;
                    _devModeVisible = false;
                  }),
                ),
              ),

            // Connection status indicator (tiny dot, top-left)
            const Positioned(
              top: 8,
              left: 8,
              child: _ConnectionDot(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RobotController>();
    final Color dotColor;

    if (controller.usbConnected || controller.wsConnected) {
      dotColor = const Color(0xFF00FF88);
    } else {
      dotColor = Colors.transparent;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _DevModePanel extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenFriendCam;

  const _DevModePanel({
    required this.onClose,
    required this.onOpenFriendCam,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RobotController>();

    return Container(
      width: 320,
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.92),
        border: const Border(
          left: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF333333)),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'DEV MODE',
                  style: TextStyle(
                    color: Color.fromARGB(255, 78, 74, 74),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child:
                      const Icon(Icons.close, color: Colors.white54, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _devSection('STATUS', [
                    _devStat(
                        'USB',
                        controller.usbConnected ? 'CONNECTED' : 'DISCONNECTED',
                        controller.usbConnected
                            ? const Color(0xFF00FF88)
                            : Colors.red),
                    _devStat(
                        'WebSocket',
                        controller.wsConnected ? 'CONNECTED' : 'DISCONNECTED',
                        controller.wsConnected
                            ? const Color(0xFF00FF88)
                            : Colors.red),
                    _devStat(
                        'Emotion',
                        controller.currentEmotion.name.toUpperCase(),
                        Colors.white70),
                    _devStat(
                        'State',
                        controller.currentState.name.toUpperCase(),
                        Colors.white70),
                  ]),
                  const SizedBox(height: 12),
                  _devSection('EMOTIONS', [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: RobotEmotion.values.map((e) {
                        return GestureDetector(
                          onTap: () => controller.setEmotion(e),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: controller.currentEmotion == e
                                  ? const Color(0xFF00FF88)
                                      .withValues(alpha: 0.15)
                                  : const Color(0xFF1A1A1A),
                              border: Border.all(
                                color: controller.currentEmotion == e
                                    ? const Color(0xFF00FF88)
                                    : const Color(0xFF333333),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              e.name,
                              style: TextStyle(
                                color: controller.currentEmotion == e
                                    ? const Color(0xFF00FF88)
                                    : Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _devSection('ACTIONS', [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _actionBtn(
                            context, 'BLINK', () => controller.triggerBlink()),
                        _actionBtn(context, 'LOOK LEFT',
                            () => controller.lookDirection('left')),
                        _actionBtn(context, 'LOOK RIGHT',
                            () => controller.lookDirection('right')),
                        _actionBtn(context, 'LOOK UP',
                            () => controller.lookDirection('up')),
                        _actionBtn(context, 'LOOK DOWN',
                            () => controller.lookDirection('down')),
                        _actionBtn(context, 'FRIEND CAM', onOpenFriendCam),
                        _actionBtn(context, 'TALKING ON',
                            () => controller.setTalking(true)),
                        _actionBtn(context, 'TALKING OFF',
                            () => controller.setTalking(false)),
                        _actionBtn(context, 'RESET', () => controller.reset()),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _devSection('WS SERVER', [
                    _devStat(
                        'URL', 'ws://[tablet-ip]:8081/robot', Colors.white38),
                    _devStat(
                        'REST', 'http://[tablet-ip]:8082/api', Colors.white38),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _devSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _devStat(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _actionBtn(BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: const Color(0xFF444444)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ),
    );
  }
}

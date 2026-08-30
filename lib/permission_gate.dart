import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Shows the robot face once all required permissions are granted.
/// If any are denied, shows a clear "Grant Permission" screen.
/// If permanently denied, shows an "Open Settings" button.
class PermissionGate extends StatefulWidget {
  final Widget child;

  const PermissionGate({super.key, required this.child});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate>
    with WidgetsBindingObserver {
  _PermState _state = _PermState.checking;

  // List of permissions the app needs
  static const _required = [
    Permission.camera,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check when user comes back from the system Settings screen
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _state != _PermState.granted) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _state = _PermState.checking);

    try {
      final results = await _required.request();

      final denied = results.entries
          .where((e) => !e.value.isGranted)
          .toList();

      if (denied.isEmpty) {
        if (mounted) setState(() => _state = _PermState.granted);
        return;
      }

      final permanent = denied
          .where((e) => e.value.isPermanentlyDenied)
          .toList();

      if (mounted) {
        setState(() => _state = permanent.isNotEmpty
            ? _PermState.permanentlyDenied
            : _PermState.denied);
      }
    } catch (e) {
      debugPrint('[PermissionGate] Error: $e');
      // On error, allow the app to run (face tracking just won't work)
      if (mounted) setState(() => _state = _PermState.granted);
    }
  }

  /// Skip — run without camera permission (face tracking disabled)
  void _skip() => setState(() => _state = _PermState.granted);

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _PermState.granted:
        return widget.child;
      case _PermState.checking:
        return const _SplashScreen(message: 'Starting…');
      case _PermState.denied:
        return _PermissionDeniedScreen(
          title: 'Camera Permission Needed',
          body: 'This robot needs the camera to track your face and move its eyes.\n\n'
              'Please grant camera access when prompted.',
          buttonLabel: 'Grant Permission',
          onPressed: _checkPermissions,
          onSkip: _skip,
        );
      case _PermState.permanentlyDenied:
        return _PermissionDeniedScreen(
          title: 'Camera Permission Blocked',
          body: 'Camera access was permanently denied.\n\n'
              'Tap "Open Settings", then enable Camera for Robot Face.',
          buttonLabel: 'Open Settings',
          onPressed: () async { await openAppSettings(); },
          onSkip: _skip,
        );
    }
  }
}

// ── States ────────────────────────────────────────────────────────────────────

enum _PermState { checking, granted, denied, permanentlyDenied }

// ── Splash (checking state) ───────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  final String message;
  const _SplashScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00FF88),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Denied / Permanently Denied screen ───────────────────────────────────────

class _PermissionDeniedScreen extends StatelessWidget {
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onPressed;
  final VoidCallback onSkip;

  const _PermissionDeniedScreen({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF00FF88).withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF00FF88),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Body
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),

                // Action button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00FF88),
                      side: const BorderSide(color: Color(0xFF00FF88)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Skip — let the face run without camera
                TextButton(
                  onPressed: onSkip,
                  child: const Text(
                    'Skip — run without camera',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

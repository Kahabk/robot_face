import 'package:flutter/material.dart';

import '../face/robot_face.dart';

class FriendCamScreen extends StatelessWidget {
  final VoidCallback? onClose;

  const FriendCamScreen({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Main Robot Face (handles its own face tracking camera stream)
          const RobotFace(),

          // Close button
          if (onClose != null)
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                tooltip: 'Close Friend Cam',
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }
}

// widgets/route/navigation_controls.dart

import 'package:flutter/material.dart';

class NavigationControls extends StatelessWidget {
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;
  final bool isPaused;

  const NavigationControls({
    Key? key,
    this.onPause,
    this.onResume,
    this.onStop,
    this.isPaused = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: isPaused ? onResume : onPause,
            icon: Icon(
              isPaused ? Icons.play_arrow : Icons.pause,
              size: 32,
              color: Colors.blue,
            ),
          ),
          IconButton(
            onPressed: onStop,
            icon: const Icon(
              Icons.stop,
              size: 32,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
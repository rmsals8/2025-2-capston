// lib/widgets/navigation/turn_by_turn_guide.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/navigation_provider.dart';

class TurnByTurnGuide extends StatelessWidget {
  const TurnByTurnGuide({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Consumer<NavigationProvider>(
          builder: (context, provider, child) {
            final status = provider.navigationStatus;
            if (status == null) return const SizedBox.shrink();

            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _buildDirectionIcon(status.nextInstruction),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status.nextInstruction,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${status.distanceToNextPoint.toStringAsFixed(0)}m 앞',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (status.isOffRoute) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.warning_amber, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '경로를 이탈했습니다. 경로를 재탐색합니다.',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDirectionIcon(String instruction) {
    IconData iconData;
    double rotationAngle = 0.0;

    if (instruction.contains('좌회전')) {
      iconData = Icons.turn_left;
    } else if (instruction.contains('우회전')) {
      iconData = Icons.turn_right;
    } else if (instruction.contains('유턴')) {
      iconData = Icons.u_turn_left;
    } else if (instruction.contains('직진')) {
      iconData = Icons.straight;
    } else if (instruction.contains('목적지')) {
      iconData = Icons.place;
    } else {
      iconData = Icons.navigation;
    }

    return Transform.rotate(
      angle: rotationAngle,
      child: Icon(
        iconData,
        color: Colors.blue,
        size: 32,
      ),
    );
  }
}
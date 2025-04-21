// lib/screens/navigation/navigation_status_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/navigation_provider.dart';

class NavigationStatusPanel extends StatelessWidget {
  const NavigationStatusPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Consumer<NavigationProvider>(
            builder: (context, provider, child) {
              final status = provider.navigationStatus;
              if (status == null) return const SizedBox.shrink();

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoColumn(
                          icon: Icons.access_time,
                          title: '예상 시간',
                          value: '${(status.estimatedTimeToDestination / 60).round()}분',
                        ),
                        _buildInfoColumn(
                          icon: Icons.speed,
                          title: '현재 속도',
                          value: '${status.speed.round()}km/h',
                        ),
                        _buildInfoColumn(
                          icon: Icons.route,
                          title: '남은 거리',
                          value: '${(status.distanceToDestination / 1000).toStringAsFixed(1)}km',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              provider.stopNavigation();
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('내비게이션 종료'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: 경로 재탐색 기능 구현
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('경로 재탐색'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import '../../models/route.dart' as app_route;

class RouteCard extends StatelessWidget {
  final app_route.Route route;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onStartNavigation;

  const RouteCard({
    Key? key,
    required this.route,
    required this.isSelected,
    required this.onTap,
    required this.onStartNavigation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.shade50 : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    route.summary.isNotEmpty ? route.summary : '추천 경로',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _getTransportIcon(route.transportMode),
                    color: route.routeColor,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${(route.distance).toStringAsFixed(1)} km'),
                  const SizedBox(width: 16),
                  Text('${(route.duration).round()} 분'),
                  const SizedBox(width: 16),
                  Text('₩${route.estimatedCost.round()}'),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onStartNavigation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: route.routeColor,
                    ),
                    child: const Text('내비게이션 시작'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTransportIcon(String transportMode) {
    switch (transportMode.toLowerCase()) {
      case 'walk':
        return Icons.directions_walk;
      case 'car':
        return Icons.directions_car;
      case 'taxi':
        return Icons.local_taxi;
      case 'bus':
        return Icons.directions_bus;
      default:
        return Icons.help_outline;
    }
  }
}
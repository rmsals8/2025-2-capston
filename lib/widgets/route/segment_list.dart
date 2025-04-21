// widgets/route/segment_list.dart

import 'package:flutter/material.dart';
import '../../models/route_segment.dart';

class SegmentList extends StatelessWidget {
  final List<RouteSegment> segments;
  final RouteSegment? currentSegment;

  const SegmentList({
    Key? key,
    required this.segments,
    this.currentSegment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final segment = segments[index];
        final isActive = segment.id == currentSegment?.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue[50] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? Colors.blue : Colors.grey[300]!,
              width: isActive ? 2 : 1,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getTransportColor(segment.transportMode),
              child: Icon(
                _getTransportIcon(segment.transportMode),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              segment.instruction,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              '${segment.distance.toStringAsFixed(1)}km • ${segment.duration}분',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            trailing: isActive
                ? const Icon(Icons.keyboard_arrow_right, color: Colors.blue)
                : null,
          ),
        );
      },
    );
  }

  IconData _getTransportIcon(String mode) {
    switch (mode) {
      case 'WALK':
        return Icons.directions_walk;
      case 'CAR':
        return Icons.directions_car;
      case 'TRANSIT':
        return Icons.directions_transit;
      default:
        return Icons.route;
    }
  }

  Color _getTransportColor(String mode) {
    switch (mode) {
      case 'WALK':
        return Colors.green;
      case 'CAR':
        return Colors.blue;
      case 'TRANSIT':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
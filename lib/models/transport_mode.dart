
// lib/models/transport_mode.dart
import 'package:flutter/material.dart';

enum TransportMode {
  driving('자동차', '🚗', Colors.blue),
  walking('도보', '🚶‍♂️', Colors.green),
  transit('대중교통', '🚌', Colors.orange);

  const TransportMode(this.label, this.icon, this.color);

  final String label;
  final String icon;
  final Color color;
}
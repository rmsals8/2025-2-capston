// lib/widgets/map/waypoint_marker.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;

class WaypointMarker {
  static Future<BitmapDescriptor> _createCustomMarkerBitmap({
    required String label,
    required int order,
    required bool isSelected,
  }) async {
    const double markerSize = 80;

    // 마커 디자인을 위한 CustomPainter 생성
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(markerSize, markerSize);
    final paint = Paint()
      ..color = isSelected ? Colors.blue : Colors.grey
      ..style = PaintingStyle.fill;

    // 원형 배경 그리기
    final circleRadius = markerSize / 3;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      circleRadius,
      paint,
    );

    // 테두리 그리기
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      circleRadius,
      borderPaint,
    );

    // 순서 번호 텍스트 그리기
    final textPainter = TextPainter(
      text: TextSpan(
        text: order.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    // 라벨 텍스트 그리기 (아래에)
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(
        (size.width - labelPainter.width) / 2,
        size.height - labelPainter.height - 4,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  static Future<Marker> create({
    required String id,
    required LatLng position,
    required String label,
    required int order,
    required bool isSelected,
    VoidCallback? onTap,
  }) async {
    final icon = await _createCustomMarkerBitmap(
      label: label,
      order: order,
      isSelected: isSelected,
    );

    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: icon,
      onTap: onTap,
      zIndex: isSelected ? 2 : 1,
      anchor: const Offset(0.5, 1.0),
    );
  }
}
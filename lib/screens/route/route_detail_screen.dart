// lib/screens/route/route_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route.dart' as route_model;
import '../../widgets/route/segment_list.dart';

class RouteDetailScreen extends StatefulWidget {
  final route_model.Route route;

  const RouteDetailScreen({
    Key? key,
    required this.route,
  }) : super(key: key);

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initializeMapData();
  }

  void _initializeMapData() {
    // 마커 생성
    _markers = {
      Marker(
        markerId: const MarkerId('start'),
        position: LatLng(
          widget.route.segments.first.startLat,
          widget.route.segments.first.startLon,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: LatLng(
          widget.route.segments.last.endLat,
          widget.route.segments.last.endLon,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    // 경로 폴리라인 생성
    List<LatLng> points = [];
    for (var segment in widget.route.segments) {
      points.add(LatLng(segment.startLat, segment.startLon));
      points.add(LatLng(segment.endLat, segment.endLon));
    }

    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: Colors.blue,
        width: 5,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('경로 상세'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  widget.route.segments.first.startLat,
                  widget.route.segments.first.startLon,
                ),
                zoom: 13,
              ),
              onMapCreated: (controller) => _mapController = controller,
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 16),
                  const Text(
                    '경로 안내',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentList(segments: widget.route.segments),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildStartNavigationButton(),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  icon: Icons.timer,
                  label: '소요 시간',
                  value: '${widget.route.totalDuration}분',
                ),
                _buildSummaryItem(
                  icon: Icons.straighten,
                  label: '총 거리',
                  value: '${widget.route.totalDistance.toStringAsFixed(1)}km',
                ),
                _buildSummaryItem(
                  icon: Icons.payment,
                  label: '예상 비용',
                  value: '${widget.route.totalCost.toInt()}원',
                ),
              ],
            ),
            if (widget.route.congestionLevel > 0.7) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Text(
                    '현재 교통 혼잡',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStartNavigationButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            // TODO: 내비게이션 시작
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '내비게이션 시작',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
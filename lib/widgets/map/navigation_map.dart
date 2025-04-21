// lib/widgets/map/navigation_map.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route_model.dart';
import '../../models/navigation_status.dart';

class NavigationMap extends StatefulWidget {
  final LatLng startLocation;
  final LatLng endLocation;
  final RouteModel route;
  final NavigationStatus? navigationStatus;

  const NavigationMap({
    Key? key,
    required this.startLocation,
    required this.endLocation,
    required this.route,
    this.navigationStatus,
  }) : super(key: key);

  @override
  State<NavigationMap> createState() => _NavigationMapState();
}

class _NavigationMapState extends State<NavigationMap> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _updateMapElements();
  }

  @override
  void didUpdateWidget(NavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationStatus != oldWidget.navigationStatus) {
      _updateCamera();
    }
    _updateMapElements();
  }

  void _updateMapElements() {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('start'),
          position: widget.startLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
        Marker(
          markerId: const MarkerId('end'),
          position: widget.endLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
        if (widget.navigationStatus != null)
          Marker(
            markerId: const MarkerId('current'),
            position: widget.navigationStatus!.currentLocation,
            rotation: widget.navigationStatus!.bearing,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
      };

      _polylines = {
        Polyline(
          polylineId: PolylineId(widget.route.id),
          points: widget.route.points,
          color: widget.route.routeColor,
          width: 5,
        ),
      };
    });
  }

  Future<void> _updateCamera() async {
    if (_mapController == null || widget.navigationStatus == null) return;

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: widget.navigationStatus!.currentLocation,
          bearing: widget.navigationStatus!.bearing,
          tilt: 45,
          zoom: 17,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.startLocation,
        zoom: 15,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        _updateCamera();
      },
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      tiltGesturesEnabled: false,
      zoomControlsEnabled: false,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/geo.dart';
import '../../../core/l10n.dart';
import '../../routes/domain/bus_route.dart';
import '../application/live_providers.dart';
import '../domain/live_bus.dart';

/// A bus to draw: its live position, what to make of it, and a short label.
class MapBus {
  const MapBus({required this.live, required this.state, required this.label});

  final LiveBus live;
  final BusLiveState state;
  final String label;
}

/// OpenStreetMap with an optional route, its stops and any number of buses.
///
/// Follows [followBusId] until the user pans or zooms, then shows a button
/// to follow it again.
class BusMap extends ConsumerStatefulWidget {
  const BusMap({
    super.key,
    this.route,
    this.homeStopId,
    this.buses = const [],
    this.followBusId,
    this.onBusTap,
  });

  final BusRoute? route;
  final String? homeStopId;
  final List<MapBus> buses;
  final String? followBusId;
  final ValueChanged<String>? onBusTap;

  @override
  ConsumerState<BusMap> createState() => _BusMapState();
}

class _BusMapState extends ConsumerState<BusMap> {
  // Ettimadai campus, until there is a route or a bus to look at.
  static const _campus = LatLng(10.9027, 76.9006);
  static const _followZoom = 15.0;

  final _controller = MapController();
  bool _ready = false;
  bool _following = true;

  /// Whether the camera has been fitted to the route and buses. Live
  /// positions usually arrive just after the map is built, so this happens
  /// on the first update that has something to show, not at build time.
  bool _fitted = false;
  late List<LatLng> _path = _pathOf(widget.route);

  static List<LatLng> _pathOf(BusRoute? route) {
    if (route == null) return const [];
    final encoded = route.path;
    if (encoded != null && encoded.isNotEmpty) return decodePolyline(encoded);
    return [for (final s in route.stops) LatLng(s.lat, s.lng)];
  }

  MapBus? get _followed =>
      widget.buses.where((b) => b.live.busId == widget.followBusId && b.state != BusLiveState.notRunning).firstOrNull;

  @override
  void didUpdateWidget(BusMap old) {
    super.didUpdateWidget(old);
    if (old.route?.id != widget.route?.id || old.route?.path != widget.route?.path) {
      _path = _pathOf(widget.route);
    }
    if (old.followBusId != widget.followBusId) _following = true;
    _fitOnce();
    _moveToFollowed();
  }

  void _fitOnce() {
    if (!_ready || _fitted || _followed != null) return;
    final points = _points();
    if (points.isEmpty) return;
    _fitted = true;
    if (points.length == 1) {
      _controller.move(points.single, _followZoom);
    } else {
      _controller.fitCamera(_fit(points));
    }
  }

  void _moveToFollowed() {
    final bus = _followed;
    if (!_ready || !_following || bus == null) return;
    final zoom = _controller.camera.zoom < 13 ? _followZoom : _controller.camera.zoom;
    _controller.move(LatLng(bus.live.lat, bus.live.lng), zoom);
  }

  List<LatLng> _points() => [
        ..._path,
        for (final b in widget.buses)
          if (b.state != BusLiveState.notRunning) LatLng(b.live.lat, b.live.lng),
      ];

  static CameraFit _fit(List<LatLng> points) =>
      CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48), maxZoom: 16);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final route = widget.route;
    final followed = _followed;
    final single = widget.buses.length == 1 ? widget.buses.single : null;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: followed == null ? _campus : LatLng(followed.live.lat, followed.live.lng),
            initialZoom: followed == null ? 12 : _followZoom,

            minZoom: 9,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onMapReady: () {
              _ready = true;
              _fitOnce();
              _moveToFollowed();
            },
            onPositionChanged: (camera, hasGesture) {
              if (!hasGesture) return;
              _fitted = true; // the student has taken over the camera
              if (_following) setState(() => _following = false);
            },
          ),
          children: [
            if (ref.watch(mapTilesEnabledProvider))
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'edu.amrita.where_is_my_bus',
              ),
            if (_path.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                  points: _path,
                  strokeWidth: 5,
                  color: scheme.primary.withValues(alpha: 0.55),
                ),
              ]),
            if (route != null)
              MarkerLayer(markers: [
                for (final stop in route.stops)
                  if (stop.id == widget.homeStopId)
                    Marker(
                      point: LatLng(stop.lat, stop.lng),
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: Icon(Icons.location_on, size: 40, color: scheme.tertiary),
                    )
                  else
                    Marker(
                      point: LatLng(stop.lat, stop.lng),
                      width: 14,
                      height: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.primary, width: 3),
                        ),
                      ),
                    ),
              ]),
            for (final bus in widget.buses)
              if (bus.state != BusLiveState.notRunning)
                _AnimatedBusMarker(
                  key: ValueKey(bus.live.busId),
                  bus: bus,
                  onTap: widget.onBusTap == null ? null : () => widget.onBusTap!(bus.live.busId),
                ),
            // Required by the OpenStreetMap tile policy. flutter_map's own
            // attribution row cannot shrink and overflows on narrow phones.
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: scheme.surface.withValues(alpha: 0.8),
                child: Text(context.l10n.mapAttribution, style: Theme.of(context).textTheme.labelSmall),
              ),
            ),
          ],
        ),
        if (!_following && followed != null)
          Positioned(
            right: 12,
            bottom: 40,
            child: FloatingActionButton.extended(
              heroTag: null,
              onPressed: () {
                setState(() => _following = true);
                _moveToFollowed();
              },
              icon: const Icon(Icons.my_location),
              label: Text(context.l10n.followBus),
            ),
          ),
        // Screen readers get the bus label even though the marker is drawn.
        if (single != null) Semantics(label: single.label, child: const SizedBox.shrink()),
      ],
    );
  }
}

/// Glides the marker to each new position instead of jumping every second.
class _AnimatedBusMarker extends StatelessWidget {
  const _AnimatedBusMarker({super.key, required this.bus, this.onTap});

  final MapBus bus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final live = bus.state == BusLiveState.live;
    final colour = live ? scheme.primary : Colors.grey.shade600;
    return TweenAnimationBuilder<LatLng>(
      tween: _LatLngTween(end: LatLng(bus.live.lat, bus.live.lng)),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.linear,
      builder: (context, point, _) => MarkerLayer(markers: [
        Marker(
          point: point,
          width: 48,
          height: 48,
          child: GestureDetector(
            onTap: onTap,
            child: Tooltip(
              message: bus.label,
              child: Container(
                decoration: BoxDecoration(
                  color: colour,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                ),
                child: Icon(Icons.directions_bus_rounded, color: live ? scheme.onPrimary : Colors.white, size: 26),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required LatLng end}) : super(begin: end, end: end);

  @override
  LatLng lerp(double t) => LatLng(
        begin!.latitude + (end!.latitude - begin!.latitude) * t,
        begin!.longitude + (end!.longitude - begin!.longitude) * t,
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/geo_point.dart';
import '../models/lesson.dart';
import '../theme/app_theme.dart';

/// Carto Voyager map of practice / instruction routes (same stack as TrekTrack).
class DrivesMap extends StatefulWidget {
  const DrivesMap({
    super.key,
    required this.lessons,
    this.liveRoute = const [],
    this.live = false,
    this.height = 220,
    this.emptyMessage = 'Practice drives with GPS show up here.',
  });

  final List<Lesson> lessons;
  final List<GeoPoint> liveRoute;
  final bool live;
  final double height;
  final String emptyMessage;

  @override
  State<DrivesMap> createState() => _DrivesMapState();
}

class _DrivesMapState extends State<DrivesMap> {
  final _map = MapController();
  final LayerHitNotifier<String> _hitNotifier = ValueNotifier(null);
  String? _selectedKey;

  @override
  void dispose() {
    _hitNotifier.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DrivesMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.live && widget.liveRoute.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitLive());
    }
  }

  void _fitLive() {
    final pts = _toLatLng(widget.liveRoute);
    if (pts.isEmpty) return;
    try {
      if (pts.length == 1) {
        _map.move(pts.first, 15);
      } else {
        _map.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(pts),
            padding: const EdgeInsets.all(36),
            maxZoom: 16,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    final lineBorder = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.85);

    final saved = widget.lessons.where((l) => l.hasMapGeometry).toList();
    final livePts = _toLatLng(widget.liveRoute);
    if (saved.isEmpty && livePts.length < 2 && livePts.isEmpty) {
      return _EmptyMapShell(height: widget.height, message: widget.emptyMessage);
    }

    final polylines = <Polyline<String>>[];
    final markers = <Marker>[];
    final allPoints = <LatLng>[...livePts];

    if (livePts.length >= 2) {
      polylines.add(
        Polyline<String>(
          points: livePts,
          hitValue: 'live',
          color: AppColors.accent,
          strokeWidth: 6,
          borderStrokeWidth: 3,
          borderColor: lineBorder,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
      markers.add(_endpoint(livePts.first, _EndpointKind.start, 'live', true));
      markers.add(_endpoint(livePts.last, _EndpointKind.end, 'live', true));
    } else if (livePts.length == 1) {
      markers.add(_endpoint(livePts.first, _EndpointKind.start, 'live', true));
    }

    for (final lesson in saved) {
      final pts = _toLatLng(lesson.route);
      if (pts.length < 2) continue;
      allPoints.addAll(pts);
      final key = lesson.id;
      final selected = _selectedKey == null || _selectedKey == key;
      final dimmed = _selectedKey != null && _selectedKey != key;
      final color = lesson.kind == DriveKind.instruction
          ? AppColors.success
          : AppColors.accent;
      polylines.add(
        Polyline<String>(
          points: pts,
          hitValue: key,
          color: color.withValues(alpha: dimmed ? 0.22 : 0.95),
          strokeWidth: selected && _selectedKey != null ? 6 : 4.5,
          borderStrokeWidth: selected && _selectedKey != null ? 3 : 2.5,
          borderColor: lineBorder.withValues(alpha: dimmed ? 0.35 : 1),
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
      markers.add(_endpoint(pts.first, _EndpointKind.start, key, !dimmed));
      markers.add(_endpoint(pts.last, _EndpointKind.end, key, !dimmed));
    }

    if (allPoints.isEmpty) {
      return _EmptyMapShell(height: widget.height, message: widget.emptyMessage);
    }

    final bounds = LatLngBounds.fromPoints(allPoints);
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.fromLTRB(40, 40, 40, 48),
                maxZoom: 15,
                minZoom: 3,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                key: ValueKey('map-$isDark'),
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.ultraforge.licenselogger',
                retinaMode: RetinaMode.isHighDensity(context),
                tileBuilder: isDark
                    ? (context, tileWidget, tile) {
                        return ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            -1, 0, 0, 0, 255,
                            0, -1, 0, 0, 255,
                            0, 0, -1, 0, 255,
                            0, 0, 0, 1, 0,
                          ]),
                          child: tileWidget,
                        );
                      }
                    : null,
              ),
              GestureDetector(
                onTap: () {
                  final hit = _hitNotifier.value;
                  if (hit == null || hit.hitValues.isEmpty) return;
                  setState(() => _selectedKey = hit.hitValues.first);
                },
                child: PolylineLayer<String>(
                  polylines: polylines,
                  hitNotifier: _hitNotifier,
                  minimumHitbox: 16,
                  simplificationTolerance: 0,
                ),
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Text(
                widget.live
                    ? 'Live drive'
                    : saved.isEmpty
                        ? 'Waiting for a GPS path'
                        : '${saved.length} drive${saved.length == 1 ? '' : 's'} · tap a route',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _endpoint(LatLng point, _EndpointKind kind, String key, bool selected) {
    return Marker(
      point: point,
      width: 36,
      height: 36,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => setState(() => _selectedKey = key),
        child: _EndpointMarker(kind: kind, emphasized: selected),
      ),
    );
  }

  static List<LatLng> _toLatLng(List<GeoPoint> raw) {
    final pts = <LatLng>[];
    for (final g in raw) {
      if (g.lat.isNaN || g.lng.isNaN) continue;
      if (g.lat < -90 || g.lat > 90 || g.lng < -180 || g.lng > 180) continue;
      final ll = LatLng(g.lat, g.lng);
      if (pts.isNotEmpty &&
          pts.last.latitude == ll.latitude &&
          pts.last.longitude == ll.longitude) {
        continue;
      }
      pts.add(ll);
    }
    return pts;
  }
}

class _EmptyMapShell extends StatelessWidget {
  const _EmptyMapShell({required this.height, required this.message});
  final double height;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(39.8283, -98.5795),
              initialZoom: 3.6,
              interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ultraforge.licenselogger',
                retinaMode: RetinaMode.isHighDensity(context),
              ),
            ],
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _EndpointKind { start, end }

class _EndpointMarker extends StatelessWidget {
  const _EndpointMarker({required this.kind, this.emphasized = true});
  final _EndpointKind kind;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final isStart = kind == _EndpointKind.start;
    final color = isStart ? AppColors.success : AppColors.accent;
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: isStart ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isStart ? null : BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: emphasized ? 2.5 : 1.5),
      ),
      alignment: Alignment.center,
      child: isStart
          ? const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            )
          : const Icon(Icons.sports_score_rounded, color: Colors.white, size: 18),
    );
  }
}

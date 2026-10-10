import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/l10n.dart';
import '../application/live_providers.dart';
import '../domain/live_bus.dart';

/// Rebuilds every second with the server's current time, so ages like
/// "updated 4 s ago" tick and a bus turns grey when updates stop.
class ServerClock extends ConsumerStatefulWidget {
  const ServerClock({super.key, required this.builder});

  final Widget Function(BuildContext context, DateTime serverNow) builder;

  @override
  ConsumerState<ServerClock> createState() => _ServerClockState();
}

class _ServerClockState extends ConsumerState<ServerClock> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offset = ref.watch(serverTimeOffsetProvider).value ?? Duration.zero;
    return widget.builder(context, ref.read(clockProvider)().add(offset));
  }
}

String formatAgo(AppLocalizations l10n, Duration age) {
  final seconds = age.inSeconds.clamp(0, 1 << 30);
  return seconds < 60 ? l10n.agoSeconds(seconds) : l10n.agoMinutes(seconds ~/ 60);
}

/// One line telling a student how far to trust what the map shows.
String liveStatusText(BuildContext context, LiveBus? bus, DateTime serverNow) {
  final l10n = context.l10n;
  if (bus == null) return l10n.busNotRunning;
  final age = serverNow.difference(bus.updatedAt);
  return switch (bus.stateAt(serverNow)) {
    BusLiveState.live => l10n.busLive(formatAgo(l10n, age)),
    BusLiveState.stale => l10n.busStale(formatAgo(l10n, age)),
    BusLiveState.offline =>
      l10n.busOffline(MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(bus.updatedAt))),
    BusLiveState.notRunning => l10n.busNotRunning,
  };
}

class LiveStatusLine extends StatelessWidget {
  const LiveStatusLine({super.key, required this.bus, required this.serverNow});

  final LiveBus? bus;
  final DateTime serverNow;

  @override
  Widget build(BuildContext context) {
    final state = bus?.stateAt(serverNow) ?? BusLiveState.notRunning;
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (state) {
      BusLiveState.live => (Icons.sensors, Colors.green.shade700),
      BusLiveState.stale => (Icons.signal_cellular_alt_1_bar, scheme.onSurfaceVariant),
      BusLiveState.offline => (Icons.signal_cellular_connected_no_internet_0_bar, scheme.onSurfaceVariant),
      BusLiveState.notRunning => (Icons.bus_alert_outlined, scheme.onSurfaceVariant),
    };
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(liveStatusText(context, bus, serverNow))),
      ],
    );
  }
}

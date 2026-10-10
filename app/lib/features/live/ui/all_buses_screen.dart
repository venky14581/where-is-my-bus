import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../routes/application/route_providers.dart';
import '../application/live_providers.dart';
import '../domain/live_bus.dart';
import 'bus_map.dart';
import 'live_status.dart';

/// Every running bus, for a student travelling somewhere else today.
class AllBusesScreen extends ConsumerStatefulWidget {
  const AllBusesScreen({super.key});

  @override
  ConsumerState<AllBusesScreen> createState() => _AllBusesScreenState();
}

class _AllBusesScreenState extends ConsumerState<AllBusesScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final live = ref.watch(allLiveBusesProvider).value ?? const <LiveBus>[];
    final buses = {for (final b in ref.watch(busesProvider).value ?? const []) b.id: b};
    final routes = {for (final r in ref.watch(routesProvider).value ?? const []) r.id: r};

    String labelFor(LiveBus bus) {
      final info = buses[bus.busId];
      final route = routes[info?.routeId];
      return [info?.number ?? bus.busId, ?route?.name].join(' · ');
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.allBusesTitle)),
      body: ServerClock(builder: (context, now) {
        final running = [
          for (final bus in live)
            if (bus.stateAt(now) != BusLiveState.notRunning) bus,
        ]..sort((a, b) => labelFor(a).compareTo(labelFor(b)));
        final selectedRoute = routes[buses[_selected]?.routeId];
        return LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              SizedBox(
                height: constraints.maxHeight * 0.6,
                child: BusMap(
                  route: selectedRoute,
                  followBusId: _selected,
                  onBusTap: (id) => setState(() => _selected = id),
                  buses: [
                    for (final bus in running) MapBus(live: bus, state: bus.stateAt(now), label: labelFor(bus)),
                  ],
                ),
              ),
              Expanded(
                child: running.isEmpty
                    ? Center(child: Text(l10n.allBusesEmpty))
                    : ListView(
                        children: [
                          for (final bus in running)
                            ListTile(
                              selected: bus.busId == _selected,
                              leading: const Icon(Icons.directions_bus_rounded),
                              title: Text(labelFor(bus)),
                              subtitle: Text(liveStatusText(context, bus, now)),
                              onTap: () => setState(() => _selected = bus.busId),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

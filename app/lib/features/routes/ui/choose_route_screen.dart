import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../routing/routes.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/session.dart';
import '../../auth/ui/widgets.dart';
import '../application/route_providers.dart';
import '../domain/bus_route.dart';
import 'scheduled_time.dart';

/// City, then route, then home stop. Shown once after sign-up, and again
/// from Change on the student home.
class ChooseRouteScreen extends ConsumerStatefulWidget {
  const ChooseRouteScreen({super.key});

  @override
  ConsumerState<ChooseRouteScreen> createState() => _ChooseRouteScreenState();
}

class _ChooseRouteScreenState extends ConsumerState<ChooseRouteScreen> {
  String? _city;
  BusRoute? _route;
  String? _stopId;
  bool _saving = false;
  String? _error;

  void _back() {
    setState(() {
      if (_route != null) {
        _route = null;
        _stopId = null;
      } else {
        _city = null;
      }
      _error = null;
    });
  }

  Future<void> _save(String uid) async {
    final route = _route!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(routeRepositoryProvider).saveHomeStop(uid: uid, routeId: route.id, stopId: _stopId!);
      if (mounted) context.go(Routes.studentHome);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.errorUnknown);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider).value;
    final profile = session is SignedIn ? session.profile : null;
    final hasRoute = profile?.routeId != null;
    final routes = ref.watch(routesProvider);

    final atFirstStep = _city == null;
    final title = _route != null
        ? l10n.chooseStopTitle
        : _city != null
            ? l10n.chooseRouteTitle
            : l10n.chooseCityTitle;

    return Scaffold(
      appBar: AppBar(
        // First-time setup has nowhere to go back to; sign-out is in the menu.
        automaticallyImplyLeading: false,
        leading: !atFirstStep
            ? BackButton(onPressed: _back)
            : hasRoute
                ? BackButton(onPressed: () => context.go(Routes.studentHome))
                : null,
        title: Text(title),
        actions: const [AccountMenu()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: routes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _Message(
                text: l10n.startupError,
                action: OutlinedButton(onPressed: () => ref.invalidate(routesProvider), child: Text(l10n.retry)),
              ),
              data: (all) {
                if (all.isEmpty) return _Message(text: l10n.noRoutesYet);
                if (_route case final route?) {
                  return _StopStep(
                    route: route,
                    selectedStopId: _stopId,
                    currentStopId: profile?.routeId == route.id ? profile?.stopId : null,
                    onSelect: (id) => setState(() => _stopId = id),
                    error: _error,
                    saving: _saving,
                    onSave: _stopId == null || profile == null ? null : () => _save(profile.uid),
                  );
                }
                if (_city case final city?) {
                  return _RouteStep(
                    routes: [for (final r in all) if (r.city == city) r],
                    currentRouteId: profile?.routeId,
                    onSelect: (route) => setState(() => _route = route),
                  );
                }
                return _CityStep(
                  routes: all,
                  onSelect: (city) => setState(() => _city = city),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CityStep extends StatelessWidget {
  const _CityStep({required this.routes, required this.onSelect});

  final List<BusRoute> routes;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final route in routes) {
      counts[route.city] = (counts[route.city] ?? 0) + 1;
    }
    final cities = counts.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final city in cities)
          _Choice(
            icon: Icons.location_city_outlined,
            title: city,
            subtitle: context.l10n.routeCount(counts[city]!),
            onTap: () => onSelect(city),
          ),
      ],
    );
  }
}

class _RouteStep extends StatelessWidget {
  const _RouteStep({required this.routes, required this.currentRouteId, required this.onSelect});

  final List<BusRoute> routes;
  final String? currentRouteId;
  final ValueChanged<BusRoute> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final route in routes)
          _Choice(
            icon: Icons.alt_route,
            title: route.name,
            subtitle: [
              l10n.stopCount(route.pickupStops.length),
              if (route.stops.isNotEmpty)
                l10n.firstPickupAt(formatScheduledTime(context, route.stops.first.scheduledTime)),
            ].join(' · '),
            selected: route.id == currentRouteId,
            onTap: () => onSelect(route),
          ),
      ],
    );
  }
}

class _StopStep extends StatelessWidget {
  const _StopStep({
    required this.route,
    required this.selectedStopId,
    required this.currentStopId,
    required this.onSelect,
    required this.error,
    required this.saving,
    required this.onSave,
  });

  final BusRoute route;
  final String? selectedStopId;
  final String? currentStopId;
  final ValueChanged<String> onSelect;
  final String? error;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(route.name, style: text.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.chooseStopBody, style: text.bodyMedium),
        ),
        Expanded(
          child: RadioGroup<String>(
            groupValue: selectedStopId ?? currentStopId,
            onChanged: (id) {
              if (id != null) onSelect(id);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final stop in route.pickupStops)
                  RadioListTile<String>(
                    value: stop.id,
                    title: Text(stop.name),
                    subtitle: Text(formatScheduledTime(context, stop.scheduledTime)),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[ErrorBanner(error!), const SizedBox(height: 12)],
              BusyButton(label: l10n.saveButton, busy: saving, onPressed: onSave),
            ],
          ),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card.outlined(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: Icon(selected ? Icons.check_circle : Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

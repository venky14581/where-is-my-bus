import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/session.dart';
import '../application/alerts_providers.dart';
import '../domain/alert_prefs.dart';

/// Which alerts a student gets. Every change saves straight away; the server
/// reads these when deciding who to notify.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  /// The latest choice, shown while it saves.
  AlertPrefs? _pending;

  /// The walk to the stop being saved; a record so "none" can be pending too.
  ({int? minutes})? _pendingWalk;

  static const _walkChoices = [2, 3, 5, 8, 10, 12, 15, 20, 25, 30, 40, 50, 60];

  Future<void> _saveWalk(String uid, int? minutes) async {
    setState(() => _pendingWalk = (minutes: minutes));
    try {
      await ref.read(alertsRepositoryProvider).saveWalkMinutes(uid, minutes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingWalk = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.settingsSaveFailed)));
    }
  }

  Future<void> _save(String uid, AlertPrefs prefs) async {
    setState(() => _pending = prefs);
    try {
      await ref.read(alertsRepositoryProvider).savePrefs(uid, prefs);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pending = null); // back to what the server has
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.settingsSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider).value;
    final profile = session is SignedIn ? session.profile : null;
    if (profile == null) return const Scaffold();
    final prefs = _pending ?? profile.alerts;
    final walk = _pendingWalk == null ? profile.walkMinutes : _pendingWalk!.minutes;
    void update(AlertPrefs next) => _save(profile.uid, next);

    // 5 Oct 2026 was a Monday; day d of that week has ISO weekday d.
    final locale = Localizations.localeOf(context).toLanguageTag();
    String dayName(int isoDay) => DateFormat.E(locale).format(DateTime(2026, 10, 4 + isoDay));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationSettingsTitle)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.settingApproaching),
            value: prefs.approaching,
            onChanged: (v) => update(prefs.copyWith(approaching: v)),
          ),
          if (prefs.approaching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settingLeadStops),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: [
                      for (final n in [1, 2, 3]) ButtonSegment(value: n, label: Text(l10n.leadStopsOption(n))),
                    ],
                    selected: {prefs.leadStops},
                    onSelectionChanged: (s) => update(prefs.copyWith(leadStops: s.first)),
                  ),
                ],
              ),
            ),
          SwitchListTile(
            title: Text(l10n.settingLeaveHome),
            subtitle: walk == null ? Text(l10n.settingLeaveHomeHelp) : null,
            value: prefs.leaveHome,
            onChanged: (v) => update(prefs.copyWith(leaveHome: v)),
          ),
          ListTile(
            title: Text(l10n.settingWalkMinutes),
            trailing: DropdownButton<int?>(
              value: walk,
              onChanged: (v) => _saveWalk(profile.uid, v),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.walkMinutesNone)),
                for (final m in {..._walkChoices, ?walk}.toList()..sort())
                  DropdownMenuItem(value: m, child: Text(l10n.walkMinutesValue(m))),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(l10n.settingTripStarted),
            value: prefs.tripStarted,
            onChanged: (v) => update(prefs.copyWith(tripStarted: v)),
          ),
          SwitchListTile(
            title: Text(l10n.settingDelays),
            value: prefs.delays,
            onChanged: (v) => update(prefs.copyWith(delays: v)),
          ),
          SwitchListTile(
            title: Text(l10n.settingAnnouncements),
            value: prefs.announcements,
            onChanged: (v) => update(prefs.copyWith(announcements: v)),
          ),
          const Divider(),
          ListTile(title: Text(l10n.settingQuietDays), subtitle: Text(l10n.settingQuietDaysHelp)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(dayName(day)),
                    selected: prefs.quietDays.contains(day),
                    onSelected: (on) => update(prefs.copyWith(
                      quietDays: on ? {...prefs.quietDays, day} : ({...prefs.quietDays}..remove(day)),
                    )),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

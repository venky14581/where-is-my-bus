import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/clock.dart';
import '../../../core/l10n.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/session.dart';
import '../../live/application/live_providers.dart';
import '../application/pass_providers.dart';
import '../domain/pass_code.dart';

/// Whether the pass is worth showing. The server decides at boarding; this
/// only spares the student a pointless QR.
enum PassStatus { none, expired, valid }

PassStatus passStatusOf(AppUser user, DateTime today) {
  final until = DateTime.tryParse(user.passValidUntil ?? '');
  if (!user.passValid || until == null) return PassStatus.none;
  final lastDay = DateTime(until.year, until.month, until.day);
  return DateTime(today.year, today.month, today.day).isAfter(lastDay) ? PassStatus.expired : PassStatus.valid;
}

/// The student's bus pass: a QR that changes every 30 seconds, so a
/// screenshot passed to a friend stops working within a minute.
class PassScreen extends ConsumerWidget {
  const PassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider).value;
    final user = session is SignedIn ? session.profile : null;
    final now = ref.watch(clockProvider)();
    final status = user == null ? PassStatus.none : passStatusOf(user, now);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myPassTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: switch (status) {
                PassStatus.none => _Message(icon: Icons.badge_outlined, text: l10n.passNone),
                PassStatus.expired => _Message(icon: Icons.event_busy, text: l10n.passExpired),
                PassStatus.valid => _ValidPass(user: user!),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ValidPass extends ConsumerStatefulWidget {
  const _ValidPass({required this.user});

  final AppUser user;

  @override
  ConsumerState<_ValidPass> createState() => _ValidPassState();
}

class _ValidPassState extends ConsumerState<_ValidPass> {
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
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final user = widget.user;
    final secret = ref.watch(passSecretProvider(user.uid)).value;
    // Server time, so a phone with the wrong clock still shows a valid code.
    final offset = ref.watch(serverTimeOffsetProvider).value ?? Duration.zero;
    final serverNow = ref.read(clockProvider)().add(offset);
    final until = DateTime.tryParse(user.passValidUntil ?? '');
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Column(
      children: [
        Text(user.name, style: text.headlineSmall, textAlign: TextAlign.center),
        if (until != null)
          Text(l10n.passValidUntil(DateFormat.yMMMd(locale).format(until)), style: text.titleMedium),
        const SizedBox(height: 20),
        if (secret == null)
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(l10n.passPreparing)]),
          )
        else ...[
          // A white card keeps the code scannable in dark mode.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: QrImageView(
              data: PassCode.make(secretBase64: secret, uid: user.uid, serverTime: serverNow),
              size: 260,
              backgroundColor: Colors.white,
              semanticsLabel: l10n.myPassTitle,
            ),
          ),
          const SizedBox(height: 12),
          Text(l10n.passRefreshesIn(PassCode.remaining(serverNow).inSeconds.clamp(1, PassCode.windowSeconds)),
              style: text.bodySmall),
        ],
        const SizedBox(height: 20),
        Text(l10n.passShowDriver, textAlign: TextAlign.center, style: text.bodyLarge),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        ],
      );
}

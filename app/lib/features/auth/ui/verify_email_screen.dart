import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../application/auth_providers.dart';
import '../domain/session.dart';
import 'form_support.dart';
import 'widgets.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> with AuthSubmit {
  static const _resendCooldown = 30;

  Timer? _timer;
  int _secondsLeft = 0;
  String? _info;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    var verified = false;
    await submit(() async {
      verified = await ref.read(authRepositoryProvider).refreshEmailVerified();
    });
    // When verified, the refreshed session moves the router on by itself.
    if (!verified && error == null && mounted) {
      setState(() => _info = context.l10n.notVerifiedYet);
    }
  }

  Future<void> _resend() async {
    final ok = await submit(() => ref.read(authRepositoryProvider).sendVerificationEmail());
    if (!ok || !mounted) return;
    setState(() {
      _info = context.l10n.verificationEmailSent;
      _secondsLeft = _resendCooldown;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider).value;
    final email = session is SignedIn ? session.email : '';
    return AuthScaffold(
      title: l10n.verifyEmailTitle,
      children: [
        Icon(Icons.mark_email_unread_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(l10n.verifyEmailBody(email)),
        const SizedBox(height: 24),
        if (error != null) ...[ErrorBanner(error!), const SizedBox(height: 16)],
        if (_info != null && error == null) ...[
          Text(_info!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 16),
        ],
        BusyButton(label: l10n.verifiedButton, busy: busy, onPressed: _checkVerified),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy || _secondsLeft > 0 ? null : _resend,
          child: Text(_secondsLeft > 0 ? l10n.resendEmailWait(_secondsLeft) : l10n.resendEmailButton),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: Text(l10n.useDifferentAccount),
        ),
      ],
    );
  }
}

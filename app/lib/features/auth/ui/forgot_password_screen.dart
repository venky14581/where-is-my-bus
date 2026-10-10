import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../application/auth_providers.dart';
import '../domain/credentials.dart';
import 'form_support.dart';
import 'widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> with AuthSubmit {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final email = normalizeEmail(_email.text);
    final ok = await submit(() => ref.read(authRepositoryProvider).sendPasswordReset(email));
    if (ok && mounted) setState(() => _sentTo = email);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sentTo = _sentTo;
    return AuthScaffold(
      title: l10n.forgotPasswordTitle,
      children: [
        if (sentTo != null) ...[
          // Same message whether or not the account exists, so this screen
          // can't be used to find out who has an account.
          Text(l10n.resetLinkSent(sentTo)),
          const SizedBox(height: 24),
          OutlinedButton(onPressed: () => context.pop(), child: Text(l10n.backToSignIn)),
        ] else ...[
          Text(l10n.forgotPasswordBody),
          const SizedBox(height: 24),
          Form(
            key: _form,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              onFieldSubmitted: (_) => _send(),
              decoration: InputDecoration(labelText: l10n.collegeEmailLabel),
              validator: Validators.collegeEmail(l10n),
            ),
          ),
          const SizedBox(height: 24),
          if (error != null) ...[ErrorBanner(error!), const SizedBox(height: 16)],
          BusyButton(label: l10n.sendResetLinkButton, busy: busy, onPressed: _send),
        ],
      ],
    );
  }
}

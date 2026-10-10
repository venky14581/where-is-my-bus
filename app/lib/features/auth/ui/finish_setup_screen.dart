import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/locale_controller.dart';
import '../application/auth_providers.dart';
import 'form_support.dart';
import 'widgets.dart';

/// For a college account whose profile was never written, for example when
/// sign-up lost its connection between creating the account and saving the
/// profile.
class FinishSetupScreen extends ConsumerStatefulWidget {
  const FinishSetupScreen({super.key});

  @override
  ConsumerState<FinishSetupScreen> createState() => _FinishSetupScreenState();
}

class _FinishSetupScreenState extends ConsumerState<FinishSetupScreen> with AuthSubmit {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await submit(() => ref.read(authRepositoryProvider).createStudentProfile(
          name: _name.text,
          language: ref.read(localeControllerProvider).languageCode,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthScaffold(
      title: l10n.finishSetupTitle,
      children: [
        Text(l10n.finishSetupBody),
        const SizedBox(height: 24),
        Form(
          key: _form,
          child: TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            maxLength: 80,
            onFieldSubmitted: (_) => _save(),
            decoration: InputDecoration(labelText: l10n.fullNameLabel, counterText: ''),
            validator: Validators.required(l10n),
          ),
        ),
        const SizedBox(height: 24),
        if (error != null) ...[ErrorBanner(error!), const SizedBox(height: 16)],
        BusyButton(label: l10n.continueButton, busy: busy, onPressed: _save),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: Text(l10n.useDifferentAccount),
        ),
      ],
    );
  }
}

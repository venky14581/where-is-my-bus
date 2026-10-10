import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/locale_controller.dart';
import '../../../routing/routes.dart';
import '../application/auth_providers.dart';
import 'form_support.dart';
import 'widgets.dart';

class StudentSignUpScreen extends ConsumerStatefulWidget {
  const StudentSignUpScreen({super.key});

  @override
  ConsumerState<StudentSignUpScreen> createState() => _StudentSignUpScreenState();
}

class _StudentSignUpScreenState extends ConsumerState<StudentSignUpScreen> with AuthSubmit {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_form.currentState!.validate()) return;
    await submit(() => ref.read(authRepositoryProvider).signUpStudent(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          language: ref.read(localeControllerProvider).languageCode,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthScaffold(
      title: l10n.studentSignUpTitle,
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  maxLength: 80,
                  decoration: InputDecoration(labelText: l10n.fullNameLabel, counterText: ''),
                  validator: Validators.required(l10n),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.collegeEmailLabel),
                  validator: Validators.collegeEmail(l10n),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  label: l10n.passwordLabel,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  validator: Validators.newPassword(l10n),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirm,
                  label: l10n.confirmPasswordLabel,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signUp(),
                  validator: (value) =>
                      value == _password.text ? null : l10n.errorPasswordsDontMatch,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (error != null) ...[ErrorBanner(error!), const SizedBox(height: 16)],
        BusyButton(label: l10n.createAccountButton, busy: busy, onPressed: _signUp),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.haveAccountPrompt),
            TextButton(
              onPressed: () => context.pushReplacement(Routes.studentSignIn),
              child: Text(l10n.signInButton),
            ),
          ],
        ),
      ],
    );
  }
}

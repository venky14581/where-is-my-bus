import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../routing/routes.dart';
import '../application/auth_providers.dart';
import 'form_support.dart';
import 'widgets.dart';

class StudentSignInScreen extends ConsumerStatefulWidget {
  const StudentSignInScreen({super.key});

  @override
  ConsumerState<StudentSignInScreen> createState() => _StudentSignInScreenState();
}

class _StudentSignInScreenState extends ConsumerState<StudentSignInScreen> with AuthSubmit {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    // On success the router moves on as soon as the session updates.
    await submit(() => ref
        .read(authRepositoryProvider)
        .signInStudent(email: _email.text, password: _password.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthScaffold(
      title: l10n.studentSignInTitle,
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                  validator: Validators.required(l10n),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push(Routes.studentForgotPassword),
            child: Text(l10n.forgotPasswordLink),
          ),
        ),
        if (error != null) ...[ErrorBanner(error!), const SizedBox(height: 16)],
        BusyButton(label: l10n.signInButton, busy: busy, onPressed: _signIn),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.noAccountPrompt),
            TextButton(
              onPressed: () => context.pushReplacement(Routes.studentSignUp),
              child: Text(l10n.createAccountLink),
            ),
          ],
        ),
      ],
    );
  }
}

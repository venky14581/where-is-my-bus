import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../core/l10n.dart';
import '../application/auth_providers.dart';
import 'form_support.dart';
import 'widgets.dart';

class DriverSignInScreen extends ConsumerStatefulWidget {
  const DriverSignInScreen({super.key});

  @override
  ConsumerState<DriverSignInScreen> createState() => _DriverSignInScreenState();
}

class _DriverSignInScreenState extends ConsumerState<DriverSignInScreen> with AuthSubmit {
  final _form = GlobalKey<FormState>();
  final _driverId = TextEditingController();
  final _pin = TextEditingController();

  @override
  bool get isDriverScreen => true;

  @override
  void dispose() {
    _driverId.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    await submit(() => ref
        .read(authRepositoryProvider)
        .signInDriver(driverId: _driverId.text, pin: _pin.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Bigger type than the student screens: drivers sign in once a day,
    // often standing beside the bus.
    const fieldStyle = TextStyle(fontSize: 22, letterSpacing: 1.5);
    return AuthScaffold(
      title: l10n.driverSignInTitle,
      children: [
        Text(l10n.driverSignInHelp(AppConfig.driverPinLength)),
        const SizedBox(height: 24),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _driverId,
                style: fieldStyle,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
                  const _UpperCase(),
                ],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.driverIdLabel, hintText: l10n.driverIdHint),
                validator: Validators.driverId(l10n),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pin,
                style: fieldStyle,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(AppConfig.driverPinLength),
                ],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _signIn(),
                decoration: InputDecoration(labelText: l10n.pinLabel),
                validator: Validators.pin(l10n),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (error != null) ...[ErrorBanner(error!), const SizedBox(height: 16)],
        SizedBox(
          height: 64,
          child: BusyButton(label: l10n.signInButton, busy: busy, onPressed: _signIn),
        ),
      ],
    );
  }
}

/// Shows the ID the way the office prints it, whatever keyboard is in use.
class _UpperCase extends TextInputFormatter {
  const _UpperCase();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

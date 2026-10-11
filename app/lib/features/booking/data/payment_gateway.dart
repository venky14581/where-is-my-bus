import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/l10n.dart';
import '../domain/booking.dart';

/// Takes the student's money for a seat. Returns null if they backed out.
abstract interface class PaymentGateway {
  Future<PaymentProof?> pay(
    BuildContext context, {
    required PaymentInfo info,
    required num fare,
    required String description,
    String? email,
  });
}

/// Picks the gateway the server asked for: a demo on the emulators, Razorpay
/// (test or live keys, set on the server) on a real project.
class AppPaymentGateway implements PaymentGateway {
  @override
  Future<PaymentProof?> pay(
    BuildContext context, {
    required PaymentInfo info,
    required num fare,
    required String description,
    String? email,
  }) =>
      switch (info.mode) {
        PaymentMode.free => Future.value(const DemoPaymentProof()),
        PaymentMode.demo => _demo(context, fare, description),
        PaymentMode.razorpay => _razorpay(info, description, email),
      };

  /// No money moves: the server accepts this only on the emulators. Looks
  /// like a real checkout so a demo shows the whole flow.
  Future<PaymentProof?> _demo(BuildContext context, num fare, String description) async {
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DemoCheckout(fare: fare, description: description),
    );
    return paid == true ? const DemoPaymentProof() : null;
  }

  /// Razorpay's checkout, on Android and iOS. Not available on the web.
  Future<PaymentProof?> _razorpay(PaymentInfo info, String description, String? email) {
    if (kIsWeb || info.keyId == null || info.orderId == null) return Future.value(null);
    final done = Completer<PaymentProof?>();
    final razorpay = Razorpay();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (!done.isCompleted) {
        done.complete(r.paymentId == null || r.signature == null
            ? null
            : RazorpayPaymentProof(paymentId: r.paymentId!, signature: r.signature!));
      }
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse _) {
      if (!done.isCompleted) done.complete(null);
    });
    razorpay.open({
      'key': info.keyId,
      'order_id': info.orderId,
      'amount': info.amountPaise,
      'currency': 'INR',
      'name': 'Where Is My Bus',
      'description': description,
      'prefill': {'email': ?email},
    });
    return done.future.whenComplete(razorpay.clear);
  }
}

enum _Method { upi, card, netbanking }

class _DemoCheckout extends StatefulWidget {
  const _DemoCheckout({required this.fare, required this.description});

  final num fare;
  final String description;

  @override
  State<_DemoCheckout> createState() => _DemoCheckoutState();
}

class _DemoCheckoutState extends State<_DemoCheckout> {
  _Method _method = _Method.upi;
  bool _processing = false;
  bool _done = false;

  Future<void> _pay() async {
    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _done = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final amount = l10n.fareRupees(widget.fare.toString());
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _done
              ? Column(
                  key: const ValueKey('done'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Icon(Icons.check_circle_rounded, size: 72, color: Colors.green.shade600),
                    const SizedBox(height: 12),
                    Text(l10n.paymentSuccess, style: text.titleLarge),
                    Text(amount, style: text.headlineSmall),
                    const SizedBox(height: 24),
                  ],
                )
              : Column(
                  key: const ValueKey('pay'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.description, style: text.titleMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(amount, style: text.displaySmall, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Text(l10n.payMethodTitle, style: text.labelLarge),
                    const SizedBox(height: 4),
                    RadioGroup<_Method>(
                      groupValue: _method,
                      onChanged: (m) => _processing || m == null ? null : setState(() => _method = m),
                      child: Column(
                        children: [
                          for (final (method, icon, label) in [
                            (_Method.upi, Icons.qr_code_rounded, l10n.payMethodUpi),
                            (_Method.card, Icons.credit_card_rounded, l10n.payMethodCard),
                            (_Method.netbanking, Icons.account_balance_rounded, l10n.payMethodNetbanking),
                          ])
                            RadioListTile<_Method>(
                              value: method,
                              secondary: Icon(icon),
                              title: Text(label),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l10n.demoPaymentBody, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _processing ? null : _pay,
                      child: _processing
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                                const SizedBox(width: 12),
                                Text(l10n.paymentProcessing),
                              ],
                            )
                          : Text(l10n.payButton(widget.fare.toString())),
                    ),
                    TextButton(
                      onPressed: _processing ? null : () => Navigator.pop(context, false),
                      child: Text(l10n.cancelButton),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

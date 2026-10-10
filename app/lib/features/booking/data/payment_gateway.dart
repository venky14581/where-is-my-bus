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
        PaymentMode.demo => _demo(context, fare),
        PaymentMode.razorpay => _razorpay(info, description, email),
      };

  /// No money moves: the server accepts this only on the emulators.
  Future<PaymentProof?> _demo(BuildContext context, num fare) async {
    final l10n = context.l10n;
    final paid = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.payments_outlined),
        title: Text(l10n.demoPaymentTitle),
        content: Text(l10n.demoPaymentBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.payButton(fare.toString()))),
        ],
      ),
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

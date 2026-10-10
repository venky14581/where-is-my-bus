import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../trip/application/trip_controller.dart';
import '../application/pass_providers.dart';
import '../data/pass_repository.dart';

/// The driver's boarding scanner: camera on top, a large verdict below.
/// The verdict stays for a few seconds, then scanning carries on.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  static const _showFor = Duration(seconds: 3);

  ScanOutcome? _outcome;
  bool _checking = false;
  String? _lastCode;
  DateTime? _lastCodeAt;
  Timer? _clear;

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }

  Future<void> _onCode(String code) async {
    final tripId = ref.read(tripControllerProvider).tripId;
    if (tripId == null || _checking) return;
    // The camera reports the same QR many times a second.
    final now = DateTime.now();
    if (code == _lastCode && _lastCodeAt != null && now.difference(_lastCodeAt!) < const Duration(seconds: 5)) return;
    _lastCode = code;
    _lastCodeAt = now;

    setState(() => _checking = true);
    final outcome = await ref.read(passRepositoryProvider).scan(tripId: tripId, code: code);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _outcome = outcome;
    });
    _clear?.cancel();
    _clear = Timer(_showFor, () {
      if (mounted) setState(() => _outcome = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tripId = ref.watch(tripControllerProvider).tripId;
    final boarded = tripId == null ? null : ref.watch(boardedCountProvider(tripId)).value;
    final scanner = ref.watch(scannerBuilderProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanTitle),
        actions: [
          if (boarded != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(l10n.boardedCount(boarded), style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ClipRect(child: scanner(context, _onCode))),
          _Verdict(outcome: _outcome, checking: _checking),
        ],
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.outcome, required this.checking});

  final ScanOutcome? outcome;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outcome = this.outcome;
    final (colour, icon, message) = switch (outcome?.result) {
      null => (Theme.of(context).colorScheme.surfaceContainerHighest, Icons.qr_code_scanner, l10n.scanHint),
      ScanResult.boarded => (Colors.green.shade700, Icons.check_circle, l10n.scanBoarded(outcome!.name)),
      ScanResult.alreadyBoarded => (Colors.green.shade700, Icons.check_circle_outline, l10n.scanAlreadyBoarded(outcome!.name)),
      ScanResult.notAPass => (Colors.red.shade700, Icons.cancel, l10n.scanNotAPass),
      ScanResult.invalidCode => (Colors.red.shade700, Icons.gpp_bad, l10n.scanInvalid),
      ScanResult.expiredCode => (Colors.orange.shade800, Icons.history, l10n.scanExpiredCode),
      ScanResult.noPass => (Colors.red.shade700, Icons.cancel, l10n.scanNoPass(outcome!.name)),
      ScanResult.passExpired => (Colors.red.shade700, Icons.event_busy, l10n.scanPassExpired(outcome!.name)),
      ScanResult.wrongRoute => (Colors.red.shade700, Icons.do_not_disturb_on, l10n.scanWrongRoute(outcome!.name)),
      ScanResult.offline => (Colors.orange.shade800, Icons.cloud_off, l10n.scanOffline),
    };
    final onColour = outcome == null ? Theme.of(context).colorScheme.onSurface : Colors.white;
    return Semantics(
      liveRegion: true,
      child: Container(
        color: colour,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Row(
          children: [
            if (checking)
              SizedBox.square(dimension: 48, child: CircularProgressIndicator(color: onColour))
            else
              Icon(icon, size: 48, color: onColour),
            const SizedBox(width: 16),
            Expanded(
              child: Text(message, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: onColour)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' as sp;

import '../../../core/config.dart';
import '../../../core/l10n.dart';
import '../../../core/ui.dart';
import '../application/safety_providers.dart';
import '../data/safety_repository.dart';

/// SOS to the transport office: the bus number and where the bus is. Asks
/// first, so a stray tap sends nothing. For the driver and for students.
class SosButton extends ConsumerStatefulWidget {
  const SosButton({super.key, this.height = 48});

  final double height;

  @override
  ConsumerState<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends ConsumerState<SosButton> {
  bool _sending = false;
  String? _message;

  Future<void> _send() async {
    final l10n = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.sos),
        title: Text(l10n.sosConfirmTitle),
        content: Text(l10n.sosConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.sosSendButton),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      _sending = true;
      _message = null;
    });
    final result = await ref.read(safetyRepositoryProvider).sendSos();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _message = switch (result) {
        SosResult.sent => l10n.sosSent,
        SosResult.noTrip => l10n.sosNoTrip,
        SosResult.offline => l10n.errorNetwork,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error, width: 2),
            ),
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.sos),
            label: Text(l10n.sosButton, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        if (_message case final message?)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(message, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

/// Makes a link a parent can open to follow this trip, and shows it to copy.
class ShareTripButton extends ConsumerStatefulWidget {
  const ShareTripButton({super.key, this.asTile = false});

  /// Drawn as an [ActionTile], to sit with the other shortcuts on the home.
  final bool asTile;

  @override
  ConsumerState<ShareTripButton> createState() => _ShareTripButtonState();
}

class _ShareTripButtonState extends ConsumerState<ShareTripButton> {
  bool _busy = false;

  Future<void> _share() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    final shared = await ref.read(safetyRepositoryProvider).shareTrip();
    if (!mounted) return;
    setState(() => _busy = false);
    final token = shared.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(shared.result == ShareResult.offline ? l10n.errorNetwork : l10n.shareNoTrip),
      ));
      return;
    }
    final link = AppConfig.shareLink(token);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.shareTripTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.shareTripBody),
            const SizedBox(height: 12),
            SelectableText(link, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.closeButton)),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.linkCopied)));
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy),
            label: Text(l10n.copyLinkButton),
          ),
          // The phone's own share sheet: WhatsApp, SMS and the rest.
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await sp.SharePlus.instance.share(sp.ShareParams(text: l10n.shareTripMessage(link), subject: l10n.shareTripTitle));
              } catch (_) {
                await Clipboard.setData(ClipboardData(text: link));
              }
            },
            icon: const Icon(Icons.share),
            label: Text(l10n.shareButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.asTile
      ? ActionTile(icon: Icons.share_location, label: context.l10n.shareTripButton, onTap: _share, busy: _busy)
      : OutlinedButton.icon(
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.share_location),
          label: Text(context.l10n.shareTripButton),
        );
}

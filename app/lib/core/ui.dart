import 'package:flutter/material.dart';

import 'theme.dart';

/// An icon in a soft round badge, used to lead cards and tiles.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.background, this.foreground, this.size = 40});

  final IconData icon;
  final Color? background;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background ?? scheme.primaryContainer, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.55, color: foreground ?? scheme.onPrimaryContainer),
    );
  }
}

/// A square shortcut: icon on top, a short label below. Several sit side by
/// side in a row, where long outlined buttons would push content down.
class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.icon, required this.label, required this.onTap, this.busy = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(Radii.medium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              busy
                  ? const SizedBox.square(dimension: 40, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2.5)))
                  : IconBadge(icon),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small rounded label with a dot or icon, for a state such as "Live".
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.background, required this.foreground, this.icon});

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: foreground), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

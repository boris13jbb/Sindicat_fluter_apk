import 'package:flutter/material.dart';

/// Chip compacto de estado (Activo, Pendiente, etc.).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.showChevron = true,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 16, color: foregroundColor),
          ],
        ],
      ),
    );
  }
}

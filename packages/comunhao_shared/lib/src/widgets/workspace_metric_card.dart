import 'package:flutter/material.dart';

class WorkspaceMetricCard extends StatelessWidget {
  const WorkspaceMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 120;
          final theme = Theme.of(context);
          final valueStyle = (compact
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.headlineSmall)
              ?.copyWith(fontWeight: FontWeight.w800);

          return Padding(
            padding: EdgeInsets.all(compact ? 10 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: compact ? 18 : 22),
                SizedBox(height: compact ? 6 : 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(value, style: valueStyle),
                        ),
                        SizedBox(height: compact ? 2 : 6),
                        Text(
                          label,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: compact ? theme.textTheme.bodySmall : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

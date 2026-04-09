import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';

class GratitudeCard extends StatelessWidget {
  final GratitudeEntry entry;
  final bool showUser;
  final VoidCallback? onDelete;

  const GratitudeCard({
    super.key,
    required this.entry,
    this.showUser = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat.yMMMd();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showUser && entry.user != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: NetworkImage(entry.user!.gravatarUrl),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.user!.displayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      dateFormat.format(entry.entryDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            if (!showUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateFormat.format(entry.entryDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            Text(
              entry.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (entry.description != null && entry.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

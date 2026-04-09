import 'package:flutter/material.dart';
import '../models.dart';

class StreakBanner extends StatelessWidget {
  final Streak streak;
  const StreakBanner({super.key, required this.streak});

  String _streakEmoji(int days) {
    if (days == 0) return '';
    if (days < 7) return '';
    if (days < 30) return '';
    if (days < 90) return '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              _streakEmoji(streak.currentStreak),
              style: const TextStyle(fontSize: 36),
            ),
            const SizedBox(height: 8),
            Text(
              streak.streakLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(label: 'Current', value: '${streak.currentStreak}', colorScheme: colorScheme),
                _StatChip(label: 'Longest', value: '${streak.longestStreak}', colorScheme: colorScheme),
                _StatChip(label: 'Total', value: '${streak.totalEntries}', colorScheme: colorScheme),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;

  const _StatChip({required this.label, required this.value, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }
}

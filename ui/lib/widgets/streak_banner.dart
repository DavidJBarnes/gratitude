import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';

class StreakBanner extends StatefulWidget {
  final Streak streak;
  const StreakBanner({super.key, required this.streak});

  @override
  State<StreakBanner> createState() => _StreakBannerState();
}

class _StreakBannerState extends State<StreakBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  static const _milestones = [7, 30, 90, 365];

  int get _nextMilestone {
    for (final m in _milestones) {
      if (widget.streak.currentStreak < m) return m;
    }
    return ((widget.streak.currentStreak ~/ 365) + 1) * 365;
  }

  int get _prevMilestone {
    int prev = 0;
    for (final m in _milestones) {
      if (widget.streak.currentStreak >= m) prev = m;
    }
    return prev;
  }

  double get _progress {
    final range = _nextMilestone - _prevMilestone;
    if (range <= 0) return 1.0;
    return (widget.streak.currentStreak - _prevMilestone) / range;
  }

  String _streakEmoji(int days) {
    if (days == 0) return '';
    if (days < 7) return '';
    if (days < 30) return '';
    if (days < 90) return '';
    return '';
  }

  String _milestoneLabel(int milestone) {
    if (milestone >= 365) return '${milestone ~/ 365}y';
    return '${milestone}d';
  }

  List<Color> _gradientColors(int days) {
    if (days == 0) return [const Color(0xFF78909C), const Color(0xFF546E7A)];
    if (days < 7) return [const Color(0xFF43A047), const Color(0xFF2E7D32)];
    if (days < 30) return [const Color(0xFF00897B), const Color(0xFF00695C)];
    if (days < 90) return [const Color(0xFFFF8F00), const Color(0xFFEF6C00)];
    return [const Color(0xFFE65100), const Color(0xFFBF360C)];
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.streak.currentStreak;
    final colors = _gradientColors(days);

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colors[0].withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    // Progress ring with streak count
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: CustomPaint(
                        painter: _RingPainter(
                          progress: _progress * _progressAnimation.value,
                          trackColor: Colors.white.withValues(alpha: 0.2),
                          fillColor: Colors.white,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _streakEmoji(days),
                                style: const TextStyle(fontSize: 22),
                              ),
                              Text(
                                '$days',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Label and milestone info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.streak.streakLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (days > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${_nextMilestone - days} days to ${_milestoneLabel(_nextMilestone)} milestone',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(label: 'Current', value: '${widget.streak.currentStreak}'),
                      Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.3)),
                      _StatItem(label: 'Longest', value: '${widget.streak.longestStreak}'),
                      Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.3)),
                      _StatItem(label: 'Total', value: '${widget.streak.totalEntries}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.75),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 8) / 2;
    const strokeWidth = 5.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Fill arc
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.trackColor != trackColor || old.fillColor != fillColor;
}

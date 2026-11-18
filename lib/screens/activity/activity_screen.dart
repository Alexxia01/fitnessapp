import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../services/step_tracker_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/number_bubble.dart';

enum _LoadState { loading, needsPermission, denied, unavailable, ready }

/// The app's third tab — today's steps, read from Apple Health / Android
/// Health Connect via [StepTrackerService]. Styled after Apple Health's own
/// "Steps" summary card (big number + hourly bar chart), redrawn in
/// Compound's teal/card language so it reads as part of this app rather
/// than a borrowed screenshot.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _service = StepTrackerService();
  final _firestoreService = FirestoreService();
  StreamSubscription<int>? _goalSub;
  int _goal = 10000;
  _LoadState _state = _LoadState.loading;
  int? _steps;
  List<int> _hourly = List.filled(24, 0);
  String? _error;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _goalSub = _firestoreService.streamStepGoal(uid).listen((g) {
      if (mounted) setState(() => _goal = g);
    }, onError: (_) {});
    _load();
  }

  @override
  void dispose() {
    _goalSub?.cancel();
    super.dispose();
  }

  Future<void> _editGoal() async {
    final newGoal = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StepGoalSheet(currentGoal: _goal),
    );
    if (newGoal == null || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await _firestoreService.saveStepGoal(uid, newGoal);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: SelectableText('Could not save goal: $e')),
      );
    }
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final has = await _service.hasPermission();
      if (!has) {
        if (mounted) setState(() => _state = _LoadState.needsPermission);
        return;
      }
      await _fetch();
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _LoadState.unavailable;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _fetch() async {
    final results = await Future.wait([
      _service.getStepsToday(),
      _service.getHourlySteps(),
    ]);
    if (!mounted) return;
    setState(() {
      _steps = results[0] as int?;
      _hourly = results[1] as List<int>;
      _state = _LoadState.ready;
    });
  }

  // DEBUG only (button hidden in release builds): writes fake steps into
  // Health Connect so the chart can be tested on an emulator.
  Future<void> _addSampleSteps() async {
    try {
      final ok = await _service.addSampleSteps();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't add sample steps — write access was denied or nothing could be written."),
          ),
        );
        return;
      }
      await _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: SelectableText('Sample steps failed: $e')),
      );
    }
  }

  Future<void> _connect() async {
    setState(() => _state = _LoadState.loading);
    try {
      final granted = await _service.requestPermission();
      if (!granted) {
        if (mounted) setState(() => _state = _LoadState.denied);
        return;
      }
      await _fetch();
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _LoadState.unavailable;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ready = _state == _LoadState.ready;
    final header = _Header(
      colors: colors,
      showHero: ready,
      steps: _steps ?? 0,
      goal: _goal,
      onRefresh: _fetch,
      onEditGoal: _editGoal,
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ready
            // Once data is in, the whole screen scrolls together: the ring
            // lives in the header, the hourly breakdown sits below it.
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HourlyCard(
                            colors: colors,
                            hourly: _hourly,
                            steps: _steps ?? 0,
                            goal: _goal,
                          ),
                          if (kDebugMode) ...[
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton.icon(
                                onPressed: _addSampleSteps,
                                icon: Icon(Icons.bug_report_outlined, size: 18, color: colors.mutedText),
                                label: Text(
                                  'Add sample steps (debug)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.mutedText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _buildBody(colors),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Everything shown under the header while NOT in the ready state
  /// (loading, asking for permission, denied, or an error).
  Widget _buildBody(AppColors colors) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());

      case _LoadState.needsPermission:
        return _MessageCard(
          colors: colors,
          icon: Icons.directions_walk,
          message: "Connect Health to see your steps here.",
          actionLabel: 'Connect',
          onAction: _connect,
        );

      case _LoadState.denied:
        return _MessageCard(
          colors: colors,
          icon: Icons.directions_walk,
          message: "Steps permission was denied. You can enable it from your phone's settings, then try again.",
          actionLabel: 'Try again',
          onAction: _load,
        );

      case _LoadState.unavailable:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 28),
                const SizedBox(height: 12),
                SelectableText(
                  'Steps unavailable: ${_error ?? 'unknown error'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.red),
                ),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),
        );

      case _LoadState.ready:
        return const SizedBox.shrink();
    }
  }
}

class _MessageCard extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageCard({
    required this.colors,
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.tealDeep, size: 40),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.mutedText),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.tealDeep,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "8 AM", "12 PM", "5 PM" for an hour of the day 0-23.
String _hourLabel(int h) {
  if (h == 0) return '12 AM';
  if (h < 12) return '$h AM';
  if (h == 12) return '12 PM';
  return '${h - 12} PM';
}

/// The teal gradient header. Once step data is loaded it doubles as the
/// hero: a big white progress ring for today's goal, with the status line
/// and an "Edit goal" link underneath — same gradient-header language as
/// the Workout and Nutrition tabs.
class _Header extends StatelessWidget {
  final AppColors colors;
  final bool showHero;
  final int steps;
  final int goal;
  final VoidCallback onRefresh;
  final VoidCallback onEditGoal;

  const _Header({
    required this.colors,
    required this.showHero,
    required this.steps,
    required this.goal,
    required this.onRefresh,
    required this.onEditGoal,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = goal <= 0 ? 0.0 : (steps / goal).clamp(0.0, 1.0);
    final reached = goal > 0 && steps >= goal;
    final remaining = goal - steps;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.tealVivid, colors.tealDeep],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activity',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How much you moved today.',
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.86)),
                    ),
                  ],
                ),
              ),
              if (showHero)
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh steps',
                ),
            ],
          ),
          if (showHero) ...[
            const SizedBox(height: 22),
            Center(
              child: SizedBox(
                width: 210,
                height: 210,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(210, 210),
                      painter: _RingPainter(
                        fraction: fraction,
                        track: Colors.white.withOpacity(0.25),
                        fill: Colors.white,
                        strokeWidth: 16,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_walk, size: 26, color: Colors.white.withOpacity(0.9)),
                        const SizedBox(height: 4),
                        Text(
                          _fmtInt(steps),
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'of ${_fmtInt(goal)} steps',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                reached ? 'Goal reached — nice work!' : '${_fmtInt(remaining)} steps to go',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: GestureDetector(
                onTap: onEditGoal,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 14, color: Colors.white.withOpacity(0.85)),
                      const SizedBox(width: 6),
                      Text(
                        'Edit goal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The hourly bar chart plus three quick stats (peak hour, active hours,
/// share of goal) in one card.
class _HourlyCard extends StatelessWidget {
  final AppColors colors;
  final List<int> hourly;
  final int steps;
  final int goal;

  const _HourlyCard({
    required this.colors,
    required this.hourly,
    required this.steps,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var peak = 0;
    var peakHour = 0;
    var activeHours = 0;
    for (var h = 0; h < hourly.length; h++) {
      if (hourly[h] > peak) {
        peak = hourly[h];
        peakHour = h;
      }
      if (hourly[h] > 0) activeHours++;
    }
    final pct = goal <= 0 ? 0 : (steps / goal * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded, color: colors.purpleDeep, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Hourly activity',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: colors.ink),
                  ),
                ],
              ),
              Text(
                'Today',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _HourlyBars(
            colors: colors,
            hourly: hourly,
            peakHour: peak > 0 ? peakHour : -1,
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: colors.border),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(
                colors: colors,
                label: 'Peak hour',
                value: peak > 0 ? _hourLabel(peakHour) : '—',
                sub: peak > 0 ? '${_fmtInt(peak)} steps' : 'no steps yet',
              ),
              _Stat(
                colors: colors,
                label: 'Active hours',
                value: '$activeHours',
                sub: 'of 24',
              ),
              _Stat(
                colors: colors,
                label: 'Of daily goal',
                value: '$pct%',
                sub: '${_fmtInt(goal)} steps',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final AppColors colors;
  final String label;
  final String value;
  final String sub;

  const _Stat({
    required this.colors,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.mutedText),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colors.ink),
          ),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 11, color: colors.mutedText)),
        ],
      ),
    );
  }
}

class _HourlyBars extends StatelessWidget {
  final AppColors colors;
  final List<int> hourly;
  final int peakHour; // -1 when there's nothing to highlight

  const _HourlyBars({
    required this.colors,
    required this.hourly,
    required this.peakHour,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = hourly.fold<int>(0, (m, v) => v > m ? v : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 130,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(color: colors.border.withOpacity(0.7)),
                ),
              ),
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var h = 0; h < 24; h++) ...[
                      if (h > 0) const SizedBox(width: 3),
                      Expanded(
                        child: _Bar(
                          fraction: maxValue == 0 ? 0 : hourly[h] / maxValue,
                          // Everything is a softer purple except the busiest
                          // hour, which gets the full color.
                          color: h == peakHour
                              ? colors.purpleDeep
                              : colors.purpleDeep.withOpacity(0.5),
                          emptyColor: colors.border,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Four equal columns, each label left-aligned, so "12 AM" starts at
        // hour 0, "6 AM" at hour 6 (25% across), "12 PM" at hour 12 (50%)
        // and "6 PM" at hour 18 (75%) — directly under the matching bars.
        Row(
          children: [
            for (final label in const ['12 AM', '6 AM', '12 PM', '6 PM'])
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, color: colors.mutedText),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;
  final Color color;
  final Color emptyColor;

  const _Bar({
    required this.fraction,
    required this.color,
    required this.emptyColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = fraction <= 0;
    // An hour with no steps still gets a tiny tick so the axis reads as
    // 24 evenly spaced slots instead of gaps.
    return FractionallySizedBox(
      heightFactor: isEmpty ? 0.03 : fraction.clamp(0.06, 1.0),
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: isEmpty ? emptyColor : color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Three faint horizontal guide lines (top, middle, baseline) behind the bars.
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final frac in const [0.0, 0.5, 1.0]) {
      final y = (size.height - 1) * frac;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

/// 6607 -> "6,607".
String _fmtInt(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color track;
  final Color fill;
  final double strokeWidth;

  _RingPainter({
    required this.fraction,
    required this.track,
    required this.fill,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (fraction <= 0) return;
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.track != track || old.fill != fill;
}

/// Bottom sheet for setting the daily steps goal.
class _StepGoalSheet extends StatefulWidget {
  final int currentGoal;
  const _StepGoalSheet({required this.currentGoal});

  @override
  State<_StepGoalSheet> createState() => _StepGoalSheetState();
}

class _StepGoalSheetState extends State<_StepGoalSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.currentGoal.toString());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final goal = int.tryParse(_controller.text) ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Daily steps goal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.ink),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Goal',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.ink),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: NumberBubble(
                    width: 150,
                    height: 52,
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    suffixText: ' steps',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final preset in const [5000, 8000, 10000, 12000])
                  ActionChip(
                    label: Text(_fmtInt(preset)),
                    onPressed: () => setState(() => _controller.text = preset.toString()),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.tealDeep,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: goal > 0 ? () => Navigator.of(context).pop(goal) : null,
                child: const Text(
                  'Save goal',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

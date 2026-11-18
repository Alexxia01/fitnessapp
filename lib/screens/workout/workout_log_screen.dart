import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/exercise.dart';
import '../../models/workout_log.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/number_bubble.dart';

class WorkoutLogScreen extends StatefulWidget {
  final String splitId;
  final String splitName;
  final Exercise exercise;

  const WorkoutLogScreen({
    super.key,
    required this.splitId,
    required this.splitName,
    required this.exercise,
  });

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  final _firestoreService = FirestoreService();
  late final List<TextEditingController> _weightControllers;
  late final List<TextEditingController> _repsControllers;
  late List<bool> _failure;
  bool _isSaving = false;
  late final Future<WorkoutLog?> _lastLogFuture;

  // A set counts as done once both fields hold a real number — no separate
  // tap-to-mark-done step. The circle is just a live reflection of that.
  bool _isSetFilled(int i) {
    final weight = double.tryParse(_weightControllers[i].text.trim());
    final reps = int.tryParse(_repsControllers[i].text.trim());
    return weight != null && reps != null;
  }

  Widget _buildSetRow(int i) {
    final colors = context.colors;
    final isLast = i == widget.exercise.targetSets - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Same card treatment as the exercise cards on the split page: a
    // uniformly-bordered surface (can't combine a non-uniform Border with
    // this asymmetric borderRadius — see _ExerciseCard in main_screen.dart
    // for why) plus a teal accent strip layered on top of the left edge,
    // instead of a plain all-around rounded rect. The shadow is plain
    // black, not tinted with `ink` — `ink` is near-white in dark mode, so
    // a tinted shadow at low opacity read as a pale halo around the card
    // instead of a shadow. Black reads as "lifted off the background" in
    // either theme without adding any color of its own.
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              bottomLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.14),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              _SetToggle(done: _isSetFilled(i)),
              const SizedBox(width: 12),
              SizedBox(
                width: 44,
                child: Text(
                  'Set ${i + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.mutedText,
                  ),
                ),
              ),
              // Fixed widths, not Expanded — so these stay the exact same
              // size on every row, whether or not the last row's
              // "To failure" chip is there competing for space. Each one
              // is its own raised "bubble" (see widgets/number_bubble.dart)
              // rather than a plain flat text field, so it pops off the
              // card surface.
              NumberBubble(
                width: 66,
                controller: _weightControllers[i],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(width: 4),
              Text(
                'kg',
                style: TextStyle(fontSize: 12, color: colors.mutedText),
              ),
              const SizedBox(width: 8),
              NumberBubble(
                width: 58,
                controller: _repsControllers[i],
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(width: 4),
              Text(
                'reps',
                style: TextStyle(fontSize: 12, color: colors.mutedText),
              ),
              if (isLast) ...[
                // Spacer, not a fixed gap — pushes the chip flush against
                // the card's right edge instead of crowding it right next
                // to the "reps" label.
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _failure[i] = !_failure[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _failure[i] ? colors.purpleDeep : colors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _failure[i]
                            ? colors.purpleDeep
                            : colors.lilacBackground,
                      ),
                    ),
                    child: Text(
                      'To failure',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _failure[i] ? Colors.white : colors.lilacText,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Teal accent strip, layered on top of the card's left edge — same
        // as the split page's exercise cards.
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 4,
            decoration: BoxDecoration(
              color: colors.tealVivid,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                bottomLeft: Radius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    final count = widget.exercise.targetSets;
    _weightControllers = List.generate(count, (_) => TextEditingController());
    _repsControllers = List.generate(count, (_) => TextEditingController());
    _failure = List.generate(count, (_) => false);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    _lastLogFuture = _firestoreService.getLatestWorkoutLog(
      uid,
      widget.exercise.id,
    );

    // Pre-fill each row with what you logged last time, if there is one.
    _lastLogFuture.then((log) {
      if (log == null || !mounted) return;
      for (var i = 0; i < count && i < log.sets.length; i++) {
        final weight = log.sets[i].weight;
        _weightControllers[i].text = weight % 1 == 0
            ? weight.toInt().toString()
            : weight.toString();
        _repsControllers[i].text = log.sets[i].reps.toString();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    for (final c in _weightControllers) {
      c.dispose();
    }
    for (final c in _repsControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _finish() async {
    final sets = <SetEntry>[];
    for (var i = 0; i < widget.exercise.targetSets; i++) {
      final weight = double.tryParse(_weightControllers[i].text);
      final reps = int.tryParse(_repsControllers[i].text);
      if (weight == null || reps == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fill in weight and reps for Set ${i + 1}.')),
        );
        return;
      }
      sets.add(
        SetEntry(
          setNumber: i + 1,
          weight: weight,
          reps: reps,
          toFailure: _failure[i],
        ),
      );
    }

    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await _firestoreService.addWorkoutLog(
        uid,
        WorkoutLog(
          id: '', // ignored — addWorkoutLog only reads toMap(), Firestore assigns the real id
          splitId: widget.splitId,
          exerciseId: widget.exercise.id,
          exerciseName: widget.exercise.name,
          loggedAt: DateTime.now(),
          sets: sets,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Previously unhandled — a failed write (bad security rules, no
      // network, etc.) left `_isSaving` stuck true forever with no sign
      // anything had gone wrong. Now it surfaces instead of failing silently.
      if (mounted) {
        setState(() => _isSaving = false);
        // Long duration + dismiss button — this is a diagnostic message,
        // not a normal transient toast, so give enough time to actually
        // read and screenshot it before it goes away on its own.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText(
              'Could not save: $e',
              style: const TextStyle(color: Colors.white),
            ),
            duration: const Duration(seconds: 30),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gradient hero
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.splitName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.exercise.name,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.lilacBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Target: ${widget.exercise.targetRepMin}–${widget.exercise.targetRepMax} reps',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: colors.lilacText,
                          ),
                        ),
                      ),
                      FutureBuilder<WorkoutLog?>(
                        future: _lastLogFuture,
                        builder: (context, snapshot) {
                          // Temporary — surfaces a failed "last time" fetch
                          // (e.g. a missing Firestore composite index) right
                          // in the UI instead of swallowing it silently, so
                          // it's visible without needing the debug console.
                          // Safe to remove once the fetch is confirmed working.
                          if (snapshot.hasError) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: SelectableText(
                                'Last-time fetch failed: ${snapshot.error}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }
                          final log = snapshot.data;
                          if (log == null || log.sets.isEmpty)
                            return const SizedBox.shrink();
                          final firstSet = log.sets.first;
                          final weightLabel = firstSet.weight % 1 == 0
                              ? firstSet.weight.toInt().toString()
                              : firstSet.weight.toString();
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colors.purpleDeep,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Last time: ${log.sets.length}×${firstSet.reps} @ $weightLabel kg',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  children: [
                    for (var i = 0; i < widget.exercise.targetSets; i++) ...[
                      if (i > 0) const SizedBox(height: 18),
                      _buildSetRow(i),
                    ],
                  ],
                ),
              ),
            ),

            // Reflective callout — only shows up when there's something
            // worth noting (you hit the top of your range last time).
            // Silent otherwise, including on your first time logging this
            // exercise — it observes, it doesn't nag every session.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: FutureBuilder<WorkoutLog?>(
                future: _lastLogFuture,
                builder: (context, snapshot) {
                  // Temporary — see the matching comment on the "Last time"
                  // pill above. Remove both once the fetch is confirmed
                  // working.
                  if (snapshot.hasError) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(
                        'Last-time fetch failed: ${snapshot.error}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }
                  final log = snapshot.data;
                  if (log == null || log.sets.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final lastSet = log.sets.last;
                  final hitTop = lastSet.reps >= widget.exercise.targetRepMax;
                  if (!hitTop) return const SizedBox.shrink();

                  final repsNote = lastSet.toFailure
                      ? '${lastSet.reps} reps, to failure'
                      : '${lastSet.reps} reps';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: colors.lilacBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'You hit the top of your range last time ($repsNote) — go up in weight today if you\'re feeling strong.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.lilacText,
                        height: 1.4,
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  // A slight neutral shadow for lift — not a colorful glow.
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: InkWell(
                    onTap: _isSaving ? null : _finish,
                    child: Ink(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.tealVivid, colors.tealDeep],
                        ),
                      ),
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Finish exercise',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The circular set-done indicator — purely a reflection of whether this
/// row's weight and reps are both filled in, not a separate tappable
/// control. Keeps the bounce-pop from the mockup: AnimationController +
/// Curves.elasticOut gives it that overshoot-then-settle feel — the curve
/// briefly scales past 1.0 before easing back, which a plain fade or
/// linear animation can't do — it just fires off typing now instead of a tap.
class _SetToggle extends StatefulWidget {
  final bool done;
  const _SetToggle({required this.done});

  @override
  State<_SetToggle> createState() => _SetToggleState();
}

class _SetToggleState extends State<_SetToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController(
    vsync: this,
    lowerBound: 0.8,
    upperBound: 1.0,
    value: widget.done ? 1.0 : 0.8,
  );

  @override
  void didUpdateWidget(covariant _SetToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.done && !oldWidget.done) {
      // Just marked done — replay the bounce from the start.
      _scale.value = 0.8;
      _scale.animateTo(
        1.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.elasticOut,
      );
    } else if (!widget.done && oldWidget.done) {
      // Unmarked — just snap back, no bounce needed going the other way.
      _scale.value = 0.8;
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.done ? colors.purpleDeep : colors.surface,
          border: Border.all(
            color: widget.done ? colors.purpleDeep : colors.lilacBackground,
            width: 2,
          ),
        ),
      ),
    );
  }
}

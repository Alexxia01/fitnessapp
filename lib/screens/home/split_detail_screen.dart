import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/exercise.dart';
import '../../models/workout_split.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../workout/add_exercise_screen.dart';
import '../workout/workout_log_screen.dart';

/// One split's exercise list — everything that used to live directly on
/// the Workout tab's home page before splits got pulled out into their own
/// cards on SplitsHomeScreen. Opened by tapping a split there, so it has
/// its own back-arrow header instead of the tab's theme-toggle header.
class SplitDetailScreen extends StatelessWidget {
  final WorkoutSplit split;
  const SplitDetailScreen({super.key, required this.split});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final colors = context.colors;
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                            const Icon(Icons.arrow_back, size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'My Split',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.86),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        split.name,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Exercise>>(
                    stream: firestoreService.streamExercises(uid, split.id),
                    builder: (context, exerciseSnapshot) {
                      if (exerciseSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading exercises:\n${exerciseSnapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }
                      if (exerciseSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final exercises = exerciseSnapshot.data ?? [];
                      if (exercises.isEmpty) {
                        return const _EmptyState(
                          message: 'No exercises in this split yet. Tap "+ Add exercise" to add your first one.',
                        );
                      }
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                        child: Column(
                          children: [
                            for (var i = 0; i < exercises.length; i++) ...[
                              if (i > 0) const SizedBox(height: 20),
                              _ExerciseCard(
                                exercise: exercises[i],
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => WorkoutLogScreen(
                                        splitId: split.id,
                                        splitName: split.name,
                                        exercise: exercises[i],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 80), // clears the floating "+ Add exercise" button
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Fixed "+ Add exercise" button, fading the list out behind it —
            // same treatment as the old MainScreen had.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.background.withOpacity(0), colors.background],
                    stops: const [0.0, 0.45],
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddExerciseScreen(splitId: split.id, splitName: split.name),
                          ),
                        );
                      },
                      child: Ink(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [colors.tealVivid, colors.tealDeep]),
                        ),
                        child: const Center(
                          child: Text(
                            '+ Add exercise',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
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

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;
  const _ExerciseCard({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      // A Stack, not a single Border, because Flutter can't combine a
      // non-uniform Border (teal on the left, border-gray on the other
      // three sides) with a borderRadius.
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${exercise.targetSets} sets',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.mutedText),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.lilacBackground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${exercise.targetRepMin}–${exercise.targetRepMax} reps',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.lilacText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: colors.tealVivid,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.colors.mutedText, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

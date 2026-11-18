import 'package:cloud_firestore/cloud_firestore.dart';

/// One set actually performed during a workout — lives inside a
/// WorkoutLog's `sets` list, not as its own Firestore document.
class SetEntry {
  final int setNumber;
  final double weight;
  final int reps;
  final bool toFailure;

  SetEntry({
    required this.setNumber,
    required this.weight,
    required this.reps,
    this.toFailure = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'setNumber': setNumber,
      'weight': weight,
      'reps': reps,
      'toFailure': toFailure,
    };
  }

  factory SetEntry.fromMap(Map<String, dynamic> map) {
    return SetEntry(
      setNumber: map['setNumber'] as int,
      weight: (map['weight'] as num).toDouble(),
      reps: map['reps'] as int,
      toFailure: map['toFailure'] as bool? ?? false,
    );
  }
}

/// A completed workout session for one exercise, stored at
/// users/{uid}/workoutLogs/{logId}. A fresh one is written every time you
/// finish an exercise — nothing here ever gets overwritten, so this is
/// your real history.
class WorkoutLog {
  final String id;
  final String splitId;
  final String exerciseId;
  final String exerciseName;
  final DateTime loggedAt;
  final List<SetEntry> sets;

  WorkoutLog({
    required this.id,
    required this.splitId,
    required this.exerciseId,
    required this.exerciseName,
    required this.loggedAt,
    required this.sets,
  });

  Map<String, dynamic> toMap() {
    return {
      'splitId': splitId,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'loggedAt': Timestamp.fromDate(loggedAt),
      'sets': sets.map((s) => s.toMap()).toList(),
    };
  }

  factory WorkoutLog.fromMap(String id, Map<String, dynamic> map) {
    return WorkoutLog(
      id: id,
      splitId: map['splitId'] as String,
      exerciseId: map['exerciseId'] as String,
      exerciseName: map['exerciseName'] as String,
      loggedAt: (map['loggedAt'] as Timestamp).toDate(),
      sets: (map['sets'] as List<dynamic>)
          .map((s) => SetEntry.fromMap(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
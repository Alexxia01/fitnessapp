import 'package:cloud_firestore/cloud_firestore.dart';

/// The one profile document every signed-in user has, stored in Firestore
/// at users/{uid}.
///
/// experienceLevel and cycleTrackingEnabled come from the onboarding
/// questions (that's the next step, after this one) — for now, every new
/// account gets sensible defaults until onboarding sets the real values.
class UserProfile {
  final String uid;
  final String email;
  final String experienceLevel; // 'new' | 'some' | 'experienced' | 'unset'
  final bool cycleTrackingEnabled;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.email,
    this.experienceLevel = 'unset',
    this.cycleTrackingEnabled = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Converts this object into the plain map Firestore stores documents as.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'experienceLevel': experienceLevel,
      'cycleTrackingEnabled': cycleTrackingEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Rebuilds a UserProfile from the map Firestore hands back on a read.
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String,
      email: map['email'] as String,
      experienceLevel: map['experienceLevel'] as String? ?? 'unset',
      cycleTrackingEnabled: map['cycleTrackingEnabled'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

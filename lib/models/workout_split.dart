

/// A single workout day within a user's split, stored at
/// users/{uid}/splits/{splitId}.
class WorkoutSplit {
  final String id;
  final String name;
  final int order;

  WorkoutSplit({
    required this.id,
    required this.name,
    required this.order,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'order': order,
    };
  }

  /// Unlike UserProfile, the id isn't stored inside the map — Firestore
  /// already gives us the document's id separately (doc.id) when we read
  /// it, so we pass it in here instead of duplicating it in the data.
  factory WorkoutSplit.fromMap(String id, Map<String, dynamic> map) {
    return WorkoutSplit(
      id: id,
      name: map['name'] as String,
      order: map['order'] as int? ?? 0,
    );
  }
}
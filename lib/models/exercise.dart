/// The target a user set for themselves for one exercise within a split,
/// stored at users/{uid}/splits/{splitId}/exercises/{exerciseId}.
class Exercise {
  final String id;
  final String name;
  final int targetSets;
  final int targetRepMin;
  final int targetRepMax;
  final int order;

  Exercise({
    required this.id,
    required this.name,
    required this.targetSets,
    required this.targetRepMin,
    required this.targetRepMax,
    required this.order,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'targetSets': targetSets,
      'targetRepMin': targetRepMin,
      'targetRepMax': targetRepMax,
      'order': order,
    };
  }

  factory Exercise.fromMap(String id, Map<String, dynamic> map) {
    return Exercise(
      id: id,
      name: map['name'] as String? ?? '',
      targetSets: map['targetSets'] as int? ?? 0,
      targetRepMin: map['targetRepMin'] as int? ?? 0,
      targetRepMax: map['targetRepMax'] as int? ?? 0,
      order: map['order'] as int? ?? 0,
    );
  }
}

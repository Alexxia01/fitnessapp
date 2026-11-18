/// Your daily calorie/macro targets — stored as a map on the user's own
/// profile doc (users/{uid}), merged in next to things like
/// `experienceLevel`, rather than its own subcollection, since there's
/// only ever one active set of goals at a time.
class NutritionGoals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const NutritionGoals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  /// Reasonable starting numbers shown in the editor the first time you
  /// open it — not a recommendation, just something more useful than a
  /// blank/zero field to start from.
  static const defaults = NutritionGoals(
    calories: 2000,
    protein: 150,
    carbs: 200,
    fat: 65,
  );

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  factory NutritionGoals.fromMap(Map<String, dynamic> map) {
    return NutritionGoals(
      calories: (map['calories'] as num?)?.toDouble() ?? defaults.calories,
      protein: (map['protein'] as num?)?.toDouble() ?? defaults.protein,
      carbs: (map['carbs'] as num?)?.toDouble() ?? defaults.carbs,
      fat: (map['fat'] as num?)?.toDouble() ?? defaults.fat,
    );
  }
}

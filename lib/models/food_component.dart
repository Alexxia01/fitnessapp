import 'food_item.dart';

/// A single food line-item stored inside a Recipe or SavedMeal — a snapshot
/// of one food's per-100g macros plus how many grams of it, so recipes and
/// saved meals keep working even if the USDA entry they came from changes
/// or the API is unreachable later. Recipe.ingredients and SavedMeal.items
/// are structurally identical lists of these; only how the whole group
/// gets logged differs (one merged entry vs. one entry per item).
class FoodComponent {
  final String description;
  final double grams;

  // Per 100g — scale by grams/100 (the getters below do this) to get what
  // this line-item actually contributes.
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double sugarPer100g;
  final double sodiumMgPer100g;
  final double cholesterolMgPer100g;

  const FoodComponent({
    required this.description,
    required this.grams,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
    required this.sugarPer100g,
    required this.sodiumMgPer100g,
    required this.cholesterolMgPer100g,
  });

  factory FoodComponent.fromFood(FoodItem food, double grams) {
    return FoodComponent(
      description: food.description,
      grams: grams,
      caloriesPer100g: food.calories,
      proteinPer100g: food.protein,
      carbsPer100g: food.carbs,
      fatPer100g: food.fat,
      fiberPer100g: food.fiber,
      sugarPer100g: food.sugar,
      sodiumMgPer100g: food.sodiumMg,
      cholesterolMgPer100g: food.cholesterolMg,
    );
  }

  /// Same food, different amount — per-100g values carry over unchanged.
  FoodComponent withGrams(double newGrams) {
    return FoodComponent(
      description: description,
      grams: newGrams,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      fiberPer100g: fiberPer100g,
      sugarPer100g: sugarPer100g,
      sodiumMgPer100g: sodiumMgPer100g,
      cholesterolMgPer100g: cholesterolMgPer100g,
    );
  }

  double get _factor => grams / 100;
  double get calories => caloriesPer100g * _factor;
  double get protein => proteinPer100g * _factor;
  double get carbs => carbsPer100g * _factor;
  double get fat => fatPer100g * _factor;
  double get fiber => fiberPer100g * _factor;
  double get sugar => sugarPer100g * _factor;
  double get sodiumMg => sodiumMgPer100g * _factor;
  double get cholesterolMg => cholesterolMgPer100g * _factor;

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'grams': grams,
      'caloriesPer100g': caloriesPer100g,
      'proteinPer100g': proteinPer100g,
      'carbsPer100g': carbsPer100g,
      'fatPer100g': fatPer100g,
      'fiberPer100g': fiberPer100g,
      'sugarPer100g': sugarPer100g,
      'sodiumMgPer100g': sodiumMgPer100g,
      'cholesterolMgPer100g': cholesterolMgPer100g,
    };
  }

  factory FoodComponent.fromMap(Map<String, dynamic> map) {
    return FoodComponent(
      description: map['description'] as String? ?? 'Food',
      grams: (map['grams'] as num?)?.toDouble() ?? 0,
      caloriesPer100g: (map['caloriesPer100g'] as num?)?.toDouble() ?? 0,
      proteinPer100g: (map['proteinPer100g'] as num?)?.toDouble() ?? 0,
      carbsPer100g: (map['carbsPer100g'] as num?)?.toDouble() ?? 0,
      fatPer100g: (map['fatPer100g'] as num?)?.toDouble() ?? 0,
      fiberPer100g: (map['fiberPer100g'] as num?)?.toDouble() ?? 0,
      sugarPer100g: (map['sugarPer100g'] as num?)?.toDouble() ?? 0,
      sodiumMgPer100g: (map['sodiumMgPer100g'] as num?)?.toDouble() ?? 0,
      cholesterolMgPer100g:
          (map['cholesterolMgPer100g'] as num?)?.toDouble() ?? 0,
    );
  }
}

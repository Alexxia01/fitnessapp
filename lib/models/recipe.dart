import 'food_component.dart';

/// A dish built from multiple ingredients with a total yield — stored at
/// users/{uid}/recipes/{recipeId}. Logging it means picking how many
/// servings you ate; per-serving macros are just the ingredient totals
/// divided by `servings`, the same math a cookbook nutrition label uses.
///
/// Unlike SavedMeal, logging a Recipe produces ONE NutritionLog entry (see
/// NutritionLog.fromRecipe) — it reads as a single dish, not a list of its
/// ingredients.
class Recipe {
  final String id;
  final String name;
  final double servings; // the yield this recipe makes, e.g. "makes 4"
  final List<FoodComponent> ingredients;

  const Recipe({
    required this.id,
    required this.name,
    required this.servings,
    required this.ingredients,
  });

  double get totalCalories => ingredients.fold(0, (s, i) => s + i.calories);
  double get totalProtein => ingredients.fold(0, (s, i) => s + i.protein);
  double get totalCarbs => ingredients.fold(0, (s, i) => s + i.carbs);
  double get totalFat => ingredients.fold(0, (s, i) => s + i.fat);
  double get totalFiber => ingredients.fold(0, (s, i) => s + i.fiber);
  double get totalSugar => ingredients.fold(0, (s, i) => s + i.sugar);
  double get totalSodiumMg => ingredients.fold(0, (s, i) => s + i.sodiumMg);
  double get totalCholesterolMg =>
      ingredients.fold(0, (s, i) => s + i.cholesterolMg);

  double get perServingCalories => servings <= 0 ? 0 : totalCalories / servings;
  double get perServingProtein => servings <= 0 ? 0 : totalProtein / servings;
  double get perServingCarbs => servings <= 0 ? 0 : totalCarbs / servings;
  double get perServingFat => servings <= 0 ? 0 : totalFat / servings;
  double get perServingFiber => servings <= 0 ? 0 : totalFiber / servings;
  double get perServingSugar => servings <= 0 ? 0 : totalSugar / servings;
  double get perServingSodiumMg =>
      servings <= 0 ? 0 : totalSodiumMg / servings;
  double get perServingCholesterolMg =>
      servings <= 0 ? 0 : totalCholesterolMg / servings;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'servings': servings,
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
    };
  }

  factory Recipe.fromMap(String id, Map<String, dynamic> map) {
    final rawIngredients = (map['ingredients'] as List<dynamic>? ?? []);
    return Recipe(
      id: id,
      name: map['name'] as String? ?? 'Recipe',
      servings: (map['servings'] as num?)?.toDouble() ?? 1,
      ingredients: rawIngredients
          .map((i) => FoodComponent.fromMap(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

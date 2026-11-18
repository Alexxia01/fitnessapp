import 'package:cloud_firestore/cloud_firestore.dart';

import 'food_component.dart';
import 'food_item.dart';
import 'recipe.dart';

/// Which section of the day a food entry belongs to.
enum Meal { breakfast, lunch, dinner, snack }

extension MealLabel on Meal {
  String get label {
    switch (this) {
      case Meal.breakfast:
        return 'Breakfast';
      case Meal.lunch:
        return 'Lunch';
      case Meal.dinner:
        return 'Dinner';
      case Meal.snack:
        return 'Snacks';
    }
  }
}

/// One food you logged, already scaled to the amount you actually ate —
/// stored at users/{uid}/nutritionLogs/{logId}. A fresh document every
/// time, same as WorkoutLog: nothing here ever gets overwritten, this is
/// your real history.
///
/// `date` is a plain 'yyyy-MM-dd' string, not just a range on `loggedAt` —
/// querying by an exact string match is simpler and avoids timezone edge
/// cases around "which day does this timestamp fall on."
class NutritionLog {
  final String id;
  final String date;
  final Meal meal;
  final String foodDescription;
  final double grams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodiumMg;
  final double cholesterolMg;
  final DateTime loggedAt;
  // Set only when this entry came from logging N servings of a Recipe —
  // `grams` isn't meaningful for a recipe (it's a whole dish, not one
  // ingredient), so the UI switches to showing "X servings" instead of
  // "Xg" when this is non-null. Null for a plain food or saved-meal-item
  // entry.
  final double? recipeServings;

  NutritionLog({
    required this.id,
    required this.date,
    required this.meal,
    required this.foodDescription,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodiumMg,
    required this.cholesterolMg,
    required this.loggedAt,
    this.recipeServings,
  });

  /// Scales a USDA FoodItem's per-100g values down to the grams actually
  /// eaten. This is the only place that math happens — everywhere else in
  /// the app just reads the already-scaled numbers back out.
  factory NutritionLog.fromFood({
    required FoodItem food,
    required double grams,
    required Meal meal,
    required String date,
  }) {
    final factor = grams / 100;
    return NutritionLog(
      id: '',
      date: date,
      meal: meal,
      foodDescription: food.description,
      grams: grams,
      calories: food.calories * factor,
      protein: food.protein * factor,
      carbs: food.carbs * factor,
      fat: food.fat * factor,
      fiber: food.fiber * factor,
      sugar: food.sugar * factor,
      sodiumMg: food.sodiumMg * factor,
      cholesterolMg: food.cholesterolMg * factor,
      loggedAt: DateTime.now(),
    );
  }

  /// A SavedMeal item logs exactly as its own entry, no scaling — the
  /// FoodComponent already represents the grams actually in the meal.
  factory NutritionLog.fromComponent({
    required FoodComponent component,
    required Meal meal,
    required String date,
  }) {
    return NutritionLog(
      id: '',
      date: date,
      meal: meal,
      foodDescription: component.description,
      grams: component.grams,
      calories: component.calories,
      protein: component.protein,
      carbs: component.carbs,
      fat: component.fat,
      fiber: component.fiber,
      sugar: component.sugar,
      sodiumMg: component.sodiumMg,
      cholesterolMg: component.cholesterolMg,
      loggedAt: DateTime.now(),
    );
  }

  /// Logs N servings of a Recipe as ONE merged entry — the per-serving
  /// macros (ingredient totals / recipe.servings) scaled by how many
  /// servings were actually eaten.
  factory NutritionLog.fromRecipe({
    required Recipe recipe,
    required double servingsEaten,
    required Meal meal,
    required String date,
  }) {
    return NutritionLog(
      id: '',
      date: date,
      meal: meal,
      foodDescription: recipe.name,
      grams: 0,
      recipeServings: servingsEaten,
      calories: recipe.perServingCalories * servingsEaten,
      protein: recipe.perServingProtein * servingsEaten,
      carbs: recipe.perServingCarbs * servingsEaten,
      fat: recipe.perServingFat * servingsEaten,
      fiber: recipe.perServingFiber * servingsEaten,
      sugar: recipe.perServingSugar * servingsEaten,
      sodiumMg: recipe.perServingSodiumMg * servingsEaten,
      cholesterolMg: recipe.perServingCholesterolMg * servingsEaten,
      loggedAt: DateTime.now(),
    );
  }

  /// True for an entry logged as N servings of a recipe (see recipeServings).
  bool get isRecipe => recipeServings != null;

  /// The editable quantity for this entry: servings for a recipe, grams for
  /// everything else.
  double get amount => recipeServings ?? grams;

  /// A copy of this entry rescaled to a new amount (same unit as [amount]),
  /// keeping its id, date, meal and original logged time. Every macro is
  /// scaled by newAmount / oldAmount — the entry stores already-scaled
  /// values rather than per-100g ones, so proportional scaling is exactly
  /// equivalent to recomputing from the food. Returns this unchanged if
  /// either amount is zero (nothing sensible to scale from/to).
  NutritionLog withAmount(double newAmount) {
    final old = amount;
    if (old <= 0 || newAmount <= 0) return this;
    final f = newAmount / old;
    return NutritionLog(
      id: id,
      date: date,
      meal: meal,
      foodDescription: foodDescription,
      grams: isRecipe ? grams : newAmount,
      recipeServings: isRecipe ? newAmount : null,
      calories: calories * f,
      protein: protein * f,
      carbs: carbs * f,
      fat: fat * f,
      fiber: fiber * f,
      sugar: sugar * f,
      sodiumMg: sodiumMg * f,
      cholesterolMg: cholesterolMg * f,
      loggedAt: loggedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'meal': meal.name,
      'foodDescription': foodDescription,
      'grams': grams,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'sodiumMg': sodiumMg,
      'cholesterolMg': cholesterolMg,
      'loggedAt': Timestamp.fromDate(loggedAt),
      if (recipeServings != null) 'recipeServings': recipeServings,
    };
  }

  factory NutritionLog.fromMap(String id, Map<String, dynamic> map) {
    return NutritionLog(
      id: id,
      date: map['date'] as String,
      meal: Meal.values.firstWhere(
        (m) => m.name == map['meal'],
        orElse: () => Meal.snack,
      ),
      foodDescription: map['foodDescription'] as String? ?? 'Food',
      grams: (map['grams'] as num).toDouble(),
      calories: (map['calories'] as num).toDouble(),
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      fiber: (map['fiber'] as num?)?.toDouble() ?? 0,
      sugar: (map['sugar'] as num?)?.toDouble() ?? 0,
      sodiumMg: (map['sodiumMg'] as num?)?.toDouble() ?? 0,
      cholesterolMg: (map['cholesterolMg'] as num?)?.toDouble() ?? 0,
      loggedAt: (map['loggedAt'] as Timestamp).toDate(),
      recipeServings: (map['recipeServings'] as num?)?.toDouble(),
    );
  }
}

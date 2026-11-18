import 'food_item.dart';

/// A USDA (or barcode-scanned) food saved for quick re-logging without
/// searching again — stored at users/{uid}/favoriteFoods/{id} as a snapshot
/// of the FoodItem at the time it was favorited. Same reasoning as
/// FoodComponent: self-contained, doesn't depend on a live lookup to
/// redisplay later.
class FavoriteFood {
  final String id;
  final String description;
  final String? brandName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodiumMg;
  final double cholesterolMg;
  final double? servingSizeGrams;

  const FavoriteFood({
    required this.id,
    required this.description,
    this.brandName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodiumMg,
    required this.cholesterolMg,
    this.servingSizeGrams,
  });

  factory FavoriteFood.fromFood(FoodItem food) {
    return FavoriteFood(
      id: '',
      description: food.description,
      brandName: food.brandName,
      calories: food.calories,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
      fiber: food.fiber,
      sugar: food.sugar,
      sodiumMg: food.sodiumMg,
      cholesterolMg: food.cholesterolMg,
      servingSizeGrams: food.servingSizeGrams,
    );
  }

  /// Converts back to a FoodItem so the existing quantity-sheet / logging
  /// flow (which works in terms of FoodItem) can be reused as-is for a
  /// favorited food, same as a fresh search result.
  FoodItem toFoodItem() {
    return FoodItem(
      fdcId: -1,
      description: description,
      brandName: brandName,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
      sodiumMg: sodiumMg,
      cholesterolMg: cholesterolMg,
      servingSizeGrams: servingSizeGrams,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'brandName': brandName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'sodiumMg': sodiumMg,
      'cholesterolMg': cholesterolMg,
      'servingSizeGrams': servingSizeGrams,
    };
  }

  factory FavoriteFood.fromMap(String id, Map<String, dynamic> map) {
    return FavoriteFood(
      id: id,
      description: map['description'] as String? ?? 'Food',
      brandName: map['brandName'] as String?,
      calories: (map['calories'] as num?)?.toDouble() ?? 0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0,
      fiber: (map['fiber'] as num?)?.toDouble() ?? 0,
      sugar: (map['sugar'] as num?)?.toDouble() ?? 0,
      sodiumMg: (map['sodiumMg'] as num?)?.toDouble() ?? 0,
      cholesterolMg: (map['cholesterolMg'] as num?)?.toDouble() ?? 0,
      servingSizeGrams: (map['servingSizeGrams'] as num?)?.toDouble(),
    );
  }
}

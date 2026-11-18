import 'food_component.dart';

/// A group of foods you log together often (e.g. "usual breakfast") —
/// stored at users/{uid}/savedMeals/{mealId}. Unlike a Recipe, this isn't a
/// single cooked dish with a yield: logging it drops each item into
/// today's log as its own separate NutritionLog entry, exactly as if
/// you'd searched and added them one at a time (see
/// NutritionLog.fromComponent).
class SavedMeal {
  final String id;
  final String name;
  final List<FoodComponent> items;

  const SavedMeal({required this.id, required this.name, required this.items});

  double get totalCalories => items.fold(0, (s, i) => s + i.calories);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory SavedMeal.fromMap(String id, Map<String, dynamic> map) {
    final rawItems = (map['items'] as List<dynamic>? ?? []);
    return SavedMeal(
      id: id,
      name: map['name'] as String? ?? 'Meal',
      items: rawItems
          .map((i) => FoodComponent.fromMap(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

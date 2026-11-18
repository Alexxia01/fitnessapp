/// A food result from the USDA FoodData Central search API — not something
/// we store ourselves, just a wrapper around what the API hands back so the
/// rest of the app doesn't need to know about USDA's JSON shape.
///
/// All nutrient fields are per 100g, which is how USDA reports them
/// regardless of food type (branded, raw, etc.) — `NutritionLog.fromFood`
/// is what scales these down to whatever amount was actually eaten.
class FoodItem {
  final int fdcId;
  final String description;
  final String? brandName;
  // 'Foundation' / 'SR Legacy' (USDA's own generic, lab-analyzed entries,
  // e.g. plain "Rice, white, long-grain, regular, raw, unenriched") vs
  // 'Branded' (a specific company's packaged product). Used to sort
  // generic results ahead of branded ones — see UsdaFoodService.
  final String? dataType;

  // Per 100g.
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodiumMg;
  final double cholesterolMg;

  // Only present for some branded foods — used as a sensible default
  // amount instead of always defaulting to 100g.
  final double? servingSizeGrams;
  final String? householdServing;

  FoodItem({
    required this.fdcId,
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
    this.householdServing,
    this.dataType,
  });

  // USDA nutrient IDs — stable across their whole database, so matching on
  // these is more reliable than matching on nutrientName strings (which
  // have small wording variants across data types).
  static const _kCalories = 1008;
  static const _kProtein = 1003;
  static const _kFat = 1004;
  static const _kCarbs = 1005;
  static const _kFiber = 1079;
  static const _kSugar = 2000;
  static const _kSodium = 1093;
  static const _kCholesterol = 1253;

  factory FoodItem.fromUsdaJson(Map<String, dynamic> json) {
    final nutrients = (json['foodNutrients'] as List<dynamic>? ?? []);

    double valueFor(int nutrientId) {
      for (final n in nutrients) {
        final map = n as Map<String, dynamic>;
        // The search endpoint uses `nutrientId`; some detail endpoints
        // nest it under `nutrient.id` instead — check both.
        final id = map['nutrientId'] ?? (map['nutrient'] as Map?)?['id'];
        if (id == nutrientId) {
          final value = map['value'] ?? map['amount'];
          if (value is num) return value.toDouble();
        }
      }
      return 0;
    }

    final servingSize = json['servingSize'];
    final servingUnit = (json['servingSizeUnit'] as String?)?.toLowerCase();

    return FoodItem(
      fdcId: json['fdcId'] as int,
      description: json['description'] as String? ?? 'Unknown food',
      brandName: json['brandOwner'] as String? ?? json['brandName'] as String?,
      calories: valueFor(_kCalories),
      protein: valueFor(_kProtein),
      carbs: valueFor(_kCarbs),
      fat: valueFor(_kFat),
      fiber: valueFor(_kFiber),
      sugar: valueFor(_kSugar),
      sodiumMg: valueFor(_kSodium),
      cholesterolMg: valueFor(_kCholesterol),
      // Only trust this as a gram amount when the unit really is grams —
      // branded foods sometimes report serving size in mL or other units,
      // which isn't something we can convert without density data.
      servingSizeGrams: (servingSize is num && servingUnit == 'g')
          ? servingSize.toDouble()
          : null,
      householdServing: json['householdServingFullText'] as String?,
      dataType: json['dataType'] as String?,
    );
  }
}

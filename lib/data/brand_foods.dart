import '../models/food_item.dart';

/// Brands the online databases don't carry, built into the app so they show
/// up in the normal food search ("elev8", "creamy rice", "cookie butter"…).
///
/// Values are per serving as listed on FatSecret (calories, protein, carbs,
/// fat only — fiber, sugar, sodium and cholesterol aren't listed there, so
/// they're 0 here). The scoop weight is an estimate: 868 g tub / 25 servings
/// ≈ 35 g. If your tub's label says otherwise, change [_elev8ScoopGrams] —
/// calories and macros per scoop stay exactly as listed either way.
const _elev8ScoopGrams = 35.0;

class _BrandFood {
  final FoodItem item;

  /// Extra words the food should also be found by (e.g. the tubs say
  /// "Creamy Rice" while some listings say "Cream of Rice").
  final String keywords;
  const _BrandFood(this.item, this.keywords);
}

FoodItem _elev8(
  String flavor, {
  required double kcal,
  required double protein,
  required double carbs,
  required double fat,
  String serving = '1 scoop',
}) {
  // FoodItem stores everything per 100 g; scale the per-scoop numbers up.
  double per100(double v) => v * 100 / _elev8ScoopGrams;
  return FoodItem(
    fdcId: -1,
    description: flavor,
    brandName: 'Elev8',
    calories: per100(kcal),
    protein: per100(protein),
    carbs: per100(carbs),
    fat: per100(fat),
    fiber: 0,
    sugar: 0,
    sodiumMg: 0,
    cholesterolMg: 0,
    servingSizeGrams: _elev8ScoopGrams,
    householdServing: serving,
    dataType: 'Branded',
  );
}

final List<_BrandFood> _brandFoods = [
  _BrandFood(_elev8('Creamy Rice, Cinnamon Roll', kcal: 120, protein: 2, carbs: 27, fat: 0), 'cream of rice'),
  _BrandFood(_elev8('Creamy Rice, Chocolate Cake', kcal: 130, protein: 3, carbs: 28, fat: 0.5), 'cream of rice'),
  _BrandFood(_elev8('Creamy Rice, Cookies N\' Cream', kcal: 120, protein: 2, carbs: 27, fat: 0), 'cream of rice cookies and cream'),
  _BrandFood(_elev8('Creamy Rice, Cookie Butter', kcal: 120, protein: 2, carbs: 27, fat: 0), 'cream of rice'),
  _BrandFood(_elev8('Creamy Rice, Peanut Butter Cup', kcal: 130, protein: 3, carbs: 27, fat: 1), 'cream of rice'),
  _BrandFood(_elev8('Creamy Rice, Maple & Brown Sugar', kcal: 120, protein: 2, carbs: 26, fat: 0), 'cream of rice maple and brown sugar'),
  _BrandFood(_elev8('Creamy Rice, Carrot Cake', kcal: 110, protein: 2, carbs: 26, fat: 0), 'cream of rice'),
  _BrandFood(_elev8('Creamy Rice, Blueberry Muffin', kcal: 120, protein: 2, carbs: 26, fat: 0), 'cream of rice'),
  _BrandFood(_elev8('Creamy Rice, Strawberry Cheesecake', kcal: 120, protein: 2, carbs: 26, fat: 0), 'cream of rice'),
  _BrandFood(_elev8('Creamy Rice, Dubai Chocolate', kcal: 140, protein: 3, carbs: 28, fat: 1), 'cream of rice'),
  _BrandFood(_elev8('Creamy Rice, Apple Pie', kcal: 120, protein: 2, carbs: 27, fat: 0), 'cream of rice'),
  _BrandFood(_elev8('Cream of Rice', kcal: 122, protein: 2, carbs: 27, fat: 0, serving: '1 serving'), 'creamy rice plain unflavored'),
];

/// Built-in brand foods whose name, brand or keywords contain every word of
/// [query].
List<FoodItem> matchBrandFoods(String query) {
  final words = query
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return [];
  return [
    for (final b in _brandFoods)
      if (words.every(
        '${b.item.description} ${b.item.brandName} ${b.keywords}'
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
            .contains,
      ))
        b.item,
  ];
}

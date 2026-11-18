import 'package:flutter/material.dart';

import '../models/food_component.dart';
import '../models/food_item.dart';
import '../services/usda_food_service.dart';
import '../theme/app_colors.dart';
import 'number_bubble.dart';

/// Shared "search a food, then say how many grams" flow used by both the
/// recipe builder and the saved-meal builder — picking an ingredient for a
/// recipe and picking an item for a saved meal are the exact same two
/// steps, just added to a different kind of list afterward. Returns null
/// if the person backs out at either step.
Future<FoodComponent?> pickIngredient(BuildContext context) async {
  final food = await showModalBottomSheet<FoodItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _IngredientSearchSheet(),
  );
  if (food == null || !context.mounted) return null;

  final grams = await _askGrams(context, food);
  if (grams == null) return null;
  return FoodComponent.fromFood(food, grams);
}

/// Change how many grams of an ingredient / saved-meal item are in a
/// recipe or meal. Returns the new grams, or null if cancelled.
Future<double?> editIngredientGrams(BuildContext context, FoodComponent component) {
  final controller = TextEditingController(
    text: component.grams == component.grams.roundToDouble()
        ? component.grams.round().toString()
        : component.grams.toStringAsFixed(1),
  );
  final colors = context.colors;
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              component.description,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.ink),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Amount',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.ink),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: NumberBubble(
                    width: 100,
                    height: 52,
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    suffixText: ' g',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.tealDeep,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: () {
                  final grams = double.tryParse(controller.text) ?? 0;
                  Navigator.of(sheetContext).pop(grams > 0 ? grams : null);
                },
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<double?> _askGrams(BuildContext context, FoodItem food) {
  final controller = TextEditingController(
    text: (food.servingSizeGrams ?? 100).toStringAsFixed(0),
  );
  final colors = context.colors;
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              food.description,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: NumberBubble(
                    width: 100,
                    height: 52,
                    controller: controller,
                    keyboardType: TextInputType.number,
                    suffixText: ' g',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.tealDeep,
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: () {
                  final grams = double.tryParse(controller.text) ?? 0;
                  Navigator.of(sheetContext).pop(grams > 0 ? grams : null);
                },
                child: const Text(
                  'Add',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A compact food search used only from inside pickIngredient — pops with
/// the chosen FoodItem instead of opening a quantity sheet itself, since
/// the grams step above handles that uniformly for both callers.
class _IngredientSearchSheet extends StatefulWidget {
  const _IngredientSearchSheet();

  @override
  State<_IngredientSearchSheet> createState() => _IngredientSearchSheetState();
}

class _IngredientSearchSheetState extends State<_IngredientSearchSheet> {
  final _usdaService = UsdaFoodService();
  final _controller = TextEditingController();
  Future<List<FoodItem>>? _resultsFuture;

  void _search() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _resultsFuture = _usdaService.searchFoods(query);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                autofocus: true,
                style: TextStyle(color: colors.ink),
                decoration: InputDecoration(
                  hintText: 'Search an ingredient…',
                  hintStyle: TextStyle(color: colors.mutedText),
                  prefixIcon: Icon(Icons.search, color: colors.mutedText),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.arrow_forward, color: colors.tealDeep),
                    onPressed: _search,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _resultsFuture == null
                  ? Center(
                      child: Text(
                        'Search USDA\'s food database.',
                        style: TextStyle(color: colors.mutedText),
                      ),
                    )
                  : FutureBuilder<List<FoodItem>>(
                      future: _resultsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: SelectableText(
                                '${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        }
                        final results = snapshot.data ?? [];
                        if (results.isEmpty) {
                          return Center(
                            child: Text('No results.', style: TextStyle(color: colors.mutedText)),
                          );
                        }
                        return ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final food = results[i];
                            return ListTile(
                              title: Text(
                                food.description,
                                style: TextStyle(color: colors.ink, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${food.calories.round()} kcal per 100g'
                                '${food.brandName != null ? ' · ${food.brandName}' : ''}',
                                style: TextStyle(color: colors.mutedText, fontSize: 12),
                              ),
                              onTap: () => Navigator.of(context).pop(food),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

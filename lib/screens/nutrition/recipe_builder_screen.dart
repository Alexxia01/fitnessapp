import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/food_component.dart';
import '../../models/recipe.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ingredient_picker.dart';
import '../../widgets/number_bubble.dart';

/// Build a recipe: give it a name, add ingredients with amounts, say how
/// many servings it makes — per-serving macros are just the ingredient
/// totals divided by that, the same math a cookbook nutrition label uses.
/// Saved to users/{uid}/recipes; logging it (picking servings eaten)
/// happens from RecipesScreen, not here.
class RecipeBuilderScreen extends StatefulWidget {
  /// When set, the screen opens pre-filled with this recipe for viewing and
  /// editing (and Save updates it) instead of starting a blank new one.
  final Recipe? existing;
  const RecipeBuilderScreen({super.key, this.existing});

  @override
  State<RecipeBuilderScreen> createState() => _RecipeBuilderScreenState();
}

class _RecipeBuilderScreenState extends State<RecipeBuilderScreen> {
  final _firestoreService = FirestoreService();
  final _nameController = TextEditingController();
  final _servingsController = TextEditingController(text: '4');
  final List<FoodComponent> _ingredients = [];
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    if (r != null) {
      _nameController.text = r.name;
      _servingsController.text = r.servings == r.servings.roundToDouble()
          ? r.servings.round().toString()
          : r.servings.toStringAsFixed(1);
      _ingredients.addAll(r.ingredients);
    }
  }

  double get _totalCalories => _ingredients.fold(0, (s, i) => s + i.calories);
  double get _totalProtein => _ingredients.fold(0, (s, i) => s + i.protein);
  double get _totalCarbs => _ingredients.fold(0, (s, i) => s + i.carbs);
  double get _totalFat => _ingredients.fold(0, (s, i) => s + i.fat);

  Future<void> _addIngredient() async {
    final component = await pickIngredient(context);
    if (component == null) return;
    setState(() => _ingredients.add(component));
  }

  Future<void> _editIngredient(int i) async {
    final grams = await editIngredientGrams(context, _ingredients[i]);
    if (grams == null) return;
    setState(() => _ingredients[i] = _ingredients[i].withGrams(grams));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final servings = double.tryParse(_servingsController.text) ?? 0;
    if (name.isEmpty || servings <= 0 || _ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Give it a name, at least one ingredient, and a servings count.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final recipe = Recipe(
        id: widget.existing?.id ?? '',
        name: name,
        servings: servings,
        ingredients: List.of(_ingredients),
      );
      if (_isEditing) {
        await _firestoreService.updateRecipe(uid, recipe);
      } else {
        await _firestoreService.addRecipe(uid, recipe);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('Could not save: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final servings = double.tryParse(_servingsController.text) ?? 0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(_isEditing ? 'Edit recipe' : 'New recipe', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: colors.ink),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            TextField(
              controller: _nameController,
              style: TextStyle(color: colors.ink),
              decoration: InputDecoration(
                labelText: 'Recipe name',
                labelStyle: TextStyle(color: colors.mutedText),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.tealDeep)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Makes',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.ink),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(18)),
                  child: NumberBubble(
                    width: 70,
                    height: 44,
                    controller: _servingsController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Text('servings', style: TextStyle(fontSize: 14, color: colors.mutedText)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ingredients',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.ink),
                ),
                TextButton.icon(
                  onPressed: _addIngredient,
                  icon: Icon(Icons.add, color: colors.tealDeep),
                  label: Text('Add', style: TextStyle(color: colors.tealDeep, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (_ingredients.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No ingredients yet.', style: TextStyle(color: colors.mutedText)),
              )
            else
              for (var i = 0; i < _ingredients.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _IngredientRow(
                    component: _ingredients[i],
                    colors: colors,
                    onTap: () => _editIngredient(i),
                    onRemove: () => setState(() => _ingredients.removeAt(i)),
                  ),
                ),
            const SizedBox(height: 20),
            if (_ingredients.isNotEmpty && servings > 0)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(color: colors.lilacBackground, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Text(
                      'Per serving',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.lilacText),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _macroPreview('${(_totalCalories / servings).round()}', 'kcal', colors),
                        _macroPreview('${(_totalProtein / servings).round()}g', 'protein', colors),
                        _macroPreview('${(_totalCarbs / servings).round()}g', 'carbs', colors),
                        _macroPreview('${(_totalFat / servings).round()}g', 'fat', colors),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.tealDeep,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _isEditing ? 'Save changes' : 'Save recipe',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroPreview(String value, String label, AppColors colors) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.ink)),
        Text(label, style: TextStyle(fontSize: 11, color: colors.mutedText)),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final FoodComponent component;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _IngredientRow({
    required this.component,
    required this.colors,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(component.description, style: TextStyle(fontWeight: FontWeight.w700, color: colors.ink)),
                Text(
                  '${component.grams.round()}g · ${component.calories.round()} kcal',
                  style: TextStyle(fontSize: 12, color: colors.mutedText),
                ),
              ],
            ),
          ),
          Icon(Icons.edit_outlined, size: 16, color: colors.mutedText),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close, size: 18, color: colors.mutedText),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/nutrition_log.dart';
import '../../models/recipe.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/number_bubble.dart';
import 'recipe_builder_screen.dart';

/// Your saved recipes — dishes built from multiple ingredients with a
/// total yield. Tap one to log some number of servings to today; the "+"
/// FAB opens the builder to create a new one.
class RecipesScreen extends StatefulWidget {
  /// The 'yyyy-MM-dd' day a logged recipe lands on (the Nutrition tab's
  /// currently selected date).
  final String date;
  const RecipesScreen({super.key, required this.date});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _firestoreService = FirestoreService();

  Future<void> _logRecipe(Recipe recipe) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogRecipeSheet(recipe: recipe),
    );
    if (result == null || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final meal = result['meal'] as Meal;
    final log = NutritionLog.fromRecipe(
      recipe: recipe,
      servingsEaten: result['servings'] as double,
      meal: meal,
      date: widget.date,
    );
    try {
      await _firestoreService.addNutritionLog(uid, log);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged ${recipe.name} to ${meal.label}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('Could not log: $e')),
        );
      }
    }
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestoreService.deleteRecipe(uid, recipe.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text('Recipes', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: colors.ink),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.tealDeep,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RecipeBuilderScreen()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Recipe>>(
          stream: _firestoreService.streamRecipes(uid),
          builder: (context, snapshot) {
            final recipes = snapshot.data ?? [];
            if (recipes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No recipes yet — build one from the + button.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.mutedText),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
              itemCount: recipes.length,
              itemBuilder: (context, i) {
                final recipe = recipes[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RecipeCard(
                    recipe: recipe,
                    colors: colors,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecipeBuilderScreen(existing: recipe),
                      ),
                    ),
                    onLog: () => _logRecipe(recipe),
                    onDelete: () => _deleteRecipe(recipe),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onLog;
  final VoidCallback onDelete;

  const _RecipeCard({
    required this.recipe,
    required this.colors,
    required this.onTap,
    required this.onLog,
    required this.onDelete,
  });

  String _fmt(double n) => n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.14), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.ink)),
                  const SizedBox(height: 4),
                  Text(
                    '${recipe.perServingCalories.round()} kcal / serving · makes ${_fmt(recipe.servings)}',
                    style: TextStyle(fontSize: 12, color: colors.mutedText),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, size: 20, color: colors.mutedText),
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete recipe',
            ),
            IconButton(
              onPressed: onLog,
              icon: Icon(Icons.add_circle, size: 28, color: colors.tealDeep),
              visualDensity: VisualDensity.compact,
              tooltip: 'Log this recipe',
            ),
          ],
        ),
      ),
    );
  }
}

class _LogRecipeSheet extends StatefulWidget {
  final Recipe recipe;
  const _LogRecipeSheet({required this.recipe});

  @override
  State<_LogRecipeSheet> createState() => _LogRecipeSheetState();
}

class _LogRecipeSheetState extends State<_LogRecipeSheet> {
  late final TextEditingController _servingsController = TextEditingController(text: '1');
  Meal _meal = Meal.snack;

  @override
  void dispose() {
    _servingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final servings = double.tryParse(_servingsController.text) ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.recipe.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.ink)),
            const SizedBox(height: 18),
            Row(
              children: [
                Text('Servings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.ink)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(18)),
                  child: NumberBubble(
                    width: 80,
                    height: 48,
                    controller: _servingsController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Meal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.ink)),
                const Spacer(),
                DropdownButton<Meal>(
                  value: _meal,
                  dropdownColor: colors.surface,
                  style: TextStyle(color: colors.ink, fontWeight: FontWeight.w600),
                  underline: const SizedBox.shrink(),
                  items: Meal.values.map((m) => DropdownMenuItem(value: m, child: Text(m.label))).toList(),
                  onChanged: (m) => setState(() => _meal = m ?? _meal),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.tealDeep,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: servings > 0
                    ? () => Navigator.of(context).pop({'servings': servings, 'meal': _meal})
                    : null,
                child: const Text('Log it', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

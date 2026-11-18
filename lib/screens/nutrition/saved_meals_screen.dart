import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/food_component.dart';
import '../../models/nutrition_log.dart';
import '../../models/saved_meal.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ingredient_picker.dart';
import '../../widgets/meal_slot_sheet.dart';

/// Your saved meals — groups of foods you log together often. Tap one to
/// drop every item straight into today's log under a chosen meal slot in
/// one go, instead of re-searching and re-adding each food individually.
class SavedMealsScreen extends StatefulWidget {
  /// The 'yyyy-MM-dd' day a logged saved meal lands on (the Nutrition tab's
  /// currently selected date).
  final String date;
  const SavedMealsScreen({super.key, required this.date});

  @override
  State<SavedMealsScreen> createState() => _SavedMealsScreenState();
}

class _SavedMealsScreenState extends State<SavedMealsScreen> {
  final _firestoreService = FirestoreService();

  /// Opens the builder sheet — blank for a new meal, pre-filled when
  /// [existing] is passed (tap a card to view/edit what's in it).
  Future<void> _openBuilder({SavedMeal? existing}) async {
    final meal = await showModalBottomSheet<SavedMeal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealBuilderSheet(existing: existing),
    );
    if (meal == null || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      if (existing != null) {
        await _firestoreService.updateSavedMeal(uid, meal);
      } else {
        await _firestoreService.addSavedMeal(uid, meal);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('Could not save: $e')),
        );
      }
    }
  }

  Future<void> _logMeal(SavedMeal meal) async {
    final chosen = await pickMealSlot(context);
    if (chosen == null || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final date = widget.date;
    try {
      for (final item in meal.items) {
        final log = NutritionLog.fromComponent(component: item, meal: chosen, date: date);
        await _firestoreService.addNutritionLog(uid, log);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged ${meal.name} to ${chosen.label}')),
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

  Future<void> _deleteMeal(SavedMeal meal) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestoreService.deleteSavedMeal(uid, meal.id);
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
        title: Text('Saved meals', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: colors.ink),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.tealDeep,
        onPressed: () => _openBuilder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: StreamBuilder<List<SavedMeal>>(
          stream: _firestoreService.streamSavedMeals(uid),
          builder: (context, snapshot) {
            final meals = snapshot.data ?? [];
            if (meals.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No saved meals yet — build one from the + button.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.mutedText),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
              itemCount: meals.length,
              itemBuilder: (context, i) {
                final meal = meals[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SavedMealCard(
                    meal: meal,
                    colors: colors,
                    onTap: () => _openBuilder(existing: meal),
                    onLog: () => _logMeal(meal),
                    onDelete: () => _deleteMeal(meal),
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

class _SavedMealCard extends StatelessWidget {
  final SavedMeal meal;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onLog;
  final VoidCallback onDelete;

  const _SavedMealCard({
    required this.meal,
    required this.colors,
    required this.onTap,
    required this.onLog,
    required this.onDelete,
  });

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
                  Text(meal.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.ink)),
                  const SizedBox(height: 4),
                  Text(
                    '${meal.items.length} item${meal.items.length == 1 ? '' : 's'} · ${meal.totalCalories.round()} kcal',
                    style: TextStyle(fontSize: 12, color: colors.mutedText),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, size: 20, color: colors.mutedText),
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete meal',
            ),
            IconButton(
              onPressed: onLog,
              icon: Icon(Icons.add_circle, size: 28, color: colors.tealDeep),
              visualDensity: VisualDensity.compact,
              tooltip: 'Log this meal',
            ),
          ],
        ),
      ),
    );
  }
}

class _MealBuilderSheet extends StatefulWidget {
  /// When set, the sheet opens pre-filled with this meal for viewing and
  /// editing, and returns it (same id) with the changes applied.
  final SavedMeal? existing;
  const _MealBuilderSheet({this.existing});

  @override
  State<_MealBuilderSheet> createState() => _MealBuilderSheetState();
}

class _MealBuilderSheetState extends State<_MealBuilderSheet> {
  final _nameController = TextEditingController();
  final List<FoodComponent> _items = [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    if (m != null) {
      _nameController.text = m.name;
      _items.addAll(m.items);
    }
  }

  Future<void> _editItem(int i) async {
    final grams = await editIngredientGrams(context, _items[i]);
    if (grams == null) return;
    setState(() => _items[i] = _items[i].withGrams(grams));
  }

  Future<void> _addItem() async {
    final component = await pickIngredient(context);
    if (component == null) return;
    setState(() => _items.add(component));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEditing ? 'Edit saved meal' : 'New saved meal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.ink)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: TextStyle(color: colors.ink),
              decoration: InputDecoration(
                labelText: 'Meal name',
                labelStyle: TextStyle(color: colors.mutedText),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.tealDeep)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.ink)),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: Icon(Icons.add, color: colors.tealDeep),
                  label: Text('Add', style: TextStyle(color: colors.tealDeep, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No items yet.', style: TextStyle(color: colors.mutedText)),
                    )
                  else
                    for (var i = 0; i < _items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => _editItem(i),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_items[i].description} · ${_items[i].grams.round()}g',
                                  style: TextStyle(color: colors.ink, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Icon(Icons.edit_outlined, size: 16, color: colors.mutedText),
                              IconButton(
                                onPressed: () => setState(() => _items.removeAt(i)),
                                icon: Icon(Icons.close, size: 18, color: colors.mutedText),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.tealDeep,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty || _items.isEmpty) return;
                  Navigator.of(context).pop(
                    SavedMeal(id: widget.existing?.id ?? '', name: name, items: List.of(_items)),
                  );
                },
                child: const Text('Save meal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/nutrition_goals.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';

/// Lets you set your daily calorie/macro targets — the numbers the
/// Nutrition screen's progress bars measure against. Opened from that
/// screen's header; pre-fills with whatever's already saved, or sensible
/// defaults the first time.
class NutritionGoalsScreen extends StatefulWidget {
  final NutritionGoals initialGoals;
  const NutritionGoalsScreen({super.key, required this.initialGoals});

  @override
  State<NutritionGoalsScreen> createState() => _NutritionGoalsScreenState();
}

class _NutritionGoalsScreenState extends State<NutritionGoalsScreen> {
  final _firestoreService = FirestoreService();
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _caloriesController = TextEditingController(
      text: widget.initialGoals.calories.toInt().toString(),
    );
    _proteinController = TextEditingController(
      text: widget.initialGoals.protein.toInt().toString(),
    );
    _carbsController = TextEditingController(
      text: widget.initialGoals.carbs.toInt().toString(),
    );
    _fatController = TextEditingController(
      text: widget.initialGoals.fat.toInt().toString(),
    );
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final calories = double.tryParse(_caloriesController.text);
    final protein = double.tryParse(_proteinController.text);
    final carbs = double.tryParse(_carbsController.text);
    final fat = double.tryParse(_fatController.text);
    if (calories == null || protein == null || carbs == null || fat == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fill in all four fields.')));
      return;
    }

    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await _firestoreService.saveNutritionGoals(
        uid,
        NutritionGoals(
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required Color accent,
  }) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.14,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 32,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.ink,
              ),
              decoration: const InputDecoration(isDense: true),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, size: 18, color: colors.mutedText),
                    const SizedBox(width: 6),
                    Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Daily goals',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'What the progress bars on the Nutrition screen measure against.',
                style: TextStyle(fontSize: 13, color: colors.mutedText),
              ),
              const SizedBox(height: 28),
              _field(
                label: 'Calories',
                controller: _caloriesController,
                accent: colors.tealVivid,
              ),
              const SizedBox(height: 14),
              _field(
                label: 'Protein (g)',
                controller: _proteinController,
                accent: colors.purpleDeep,
              ),
              const SizedBox(height: 14),
              _field(
                label: 'Carbs (g)',
                controller: _carbsController,
                accent: colors.lilacText,
              ),
              const SizedBox(height: 14),
              _field(
                label: 'Fat (g)',
                controller: _fatController,
                accent: colors.mutedText,
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: InkWell(
                    onTap: _isSaving ? null : _save,
                    child: Ink(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.tealVivid, colors.tealDeep],
                        ),
                      ),
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save goals',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

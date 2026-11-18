import 'package:flutter/material.dart';

import '../models/nutrition_log.dart';
import '../theme/app_colors.dart';

/// A small bottom sheet asking "which meal?" — used anywhere logging
/// something (a favorite food, a saved meal) needs to know the meal slot
/// but isn't already inside a specific meal's context the way
/// FoodSearchScreen is (it's always opened for one particular meal
/// already).
Future<Meal?> pickMealSlot(BuildContext context) {
  return showModalBottomSheet<Meal>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final colors = sheetContext.colors;
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Add to which meal?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 8),
            for (final meal in Meal.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  meal.label,
                  style: TextStyle(color: colors.ink, fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.of(sheetContext).pop(meal),
              ),
          ],
        ),
      );
    },
  );
}

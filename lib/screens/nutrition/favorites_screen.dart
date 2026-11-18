import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/favorite_food.dart';
import '../../models/nutrition_log.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/meal_slot_sheet.dart';
import 'recipes_screen.dart';
import 'saved_meals_screen.dart';

/// The "quick add" hub — favorited individual foods front and center for
/// one-tap logging, plus quick links into your recipes and saved meals.
/// This is what replaces having to re-search something you eat all the
/// time. Reached from the bookmark icon on the Nutrition tab's header.
class FavoritesScreen extends StatefulWidget {
  /// The 'yyyy-MM-dd' day everything logged from here lands on — whichever
  /// date the Nutrition tab is currently showing, not necessarily today.
  final String date;
  const FavoritesScreen({super.key, required this.date});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _firestoreService = FirestoreService();

  Future<void> _quickLog(FavoriteFood favorite) async {
    final meal = await pickMealSlot(context);
    if (meal == null || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final grams = favorite.servingSizeGrams ?? 100;
    final log = NutritionLog.fromFood(
      food: favorite.toFoodItem(),
      grams: grams,
      meal: meal,
      date: widget.date,
    );
    try {
      await _firestoreService.addNutritionLog(uid, log);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged ${favorite.description} to ${meal.label}')),
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

  Future<void> _removeFavorite(FavoriteFood favorite) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestoreService.deleteFavoriteFood(uid, favorite.id);
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
        title: Text('Quick add', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: colors.ink),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('Favorite foods', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.ink)),
            const SizedBox(height: 4),
            Text(
              'Tap the star on any search result to add it here.',
              style: TextStyle(fontSize: 12, color: colors.mutedText),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<FavoriteFood>>(
              stream: _firestoreService.streamFavoriteFoods(uid),
              builder: (context, snapshot) {
                final favorites = snapshot.data ?? [];
                if (favorites.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('No favorites yet.', style: TextStyle(color: colors.mutedText)),
                  );
                }
                return Column(
                  children: [
                    for (final favorite in favorites)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _FavoriteFoodRow(
                          favorite: favorite,
                          colors: colors,
                          onTap: () => _quickLog(favorite),
                          onRemove: () => _removeFavorite(favorite),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            _SectionLink(
              title: 'Recipes',
              subtitle: 'Dishes built from ingredients, logged by the serving.',
              icon: Icons.ramen_dining,
              colors: colors,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RecipesScreen(date: widget.date)),
              ),
            ),
            const SizedBox(height: 12),
            _SectionLink(
              title: 'Saved meals',
              subtitle: 'Groups of foods you log together often.',
              icon: Icons.set_meal,
              colors: colors,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SavedMealsScreen(date: widget.date)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteFoodRow extends StatelessWidget {
  final FavoriteFood favorite;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteFoodRow({required this.favorite, required this.colors, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.14), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    favorite.description,
                    style: TextStyle(fontWeight: FontWeight.w700, color: colors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text('${favorite.calories.round()} kcal per 100g', style: TextStyle(fontSize: 12, color: colors.mutedText)),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.star, color: colors.purpleDeep, size: 20),
              tooltip: 'Remove from favorites',
              visualDensity: VisualDensity.compact,
            ),
            Icon(Icons.add_circle, color: colors.tealDeep, size: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionLink extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final AppColors colors;
  final VoidCallback onTap;

  const _SectionLink({required this.title, required this.subtitle, required this.icon, required this.colors, required this.onTap});

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
            Icon(icon, color: colors.tealDeep, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: colors.mutedText)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.mutedText),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/favorite_food.dart';
import '../../models/food_item.dart';
import '../../models/nutrition_log.dart';
import '../../models/recipe.dart';
import '../../models/saved_meal.dart';
import '../../services/firestore_service.dart';
import '../../services/open_food_facts_service.dart';
import '../../services/usda_food_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/number_bubble.dart';
import 'barcode_scan_screen.dart';

/// Search USDA's food database and log something to one meal, on one day.
/// Opened from the "+ Add" button on a meal section of NutritionScreen,
/// which already knows which meal/day this is for — this screen just
/// needs to find the food and the amount.
enum _SearchTab { all, favorites, custom }

class FoodSearchScreen extends StatefulWidget {
  final Meal meal;
  final String date;
  const FoodSearchScreen({super.key, required this.meal, required this.date});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _usdaService = UsdaFoodService();
  final _offService = OpenFoodFactsService();
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  Future<List<FoodItem>>? _resultsFuture;

  // Which foods are currently favorited, so each result's star can show
  // filled vs. outline. Favorites carry no USDA id (they're snapshots), so
  // a food is matched by description + brand. Maps that key -> the favorite
  // document's id, which is what un-favoriting needs to delete.
  StreamSubscription<List<FavoriteFood>>? _favoritesSub;
  Map<String, String> _favoriteIds = {};
  // Taps applied to the star immediately, before Firestore's stream
  // catches up; cleared every time the stream emits.
  final Map<String, bool> _optimistic = {};

  // Your own recipes and saved meals, searched alongside USDA so something
  // you built shows up in the results (tagged as yours) without having to
  // leave this screen. Filtered locally by name against [_query].
  StreamSubscription<List<Recipe>>? _recipesSub;
  StreamSubscription<List<SavedMeal>>? _savedMealsSub;
  List<Recipe> _recipes = [];
  List<SavedMeal> _savedMeals = [];
  String _query = '';

  // All / Favorites / Custom, like Cronometer's tabs under the search box.
  _SearchTab _tab = _SearchTab.all;
  List<FavoriteFood> _favoriteList = [];

  static String _favKey(String description, String? brand) =>
      '${description.trim().toLowerCase()}|${(brand ?? '').trim().toLowerCase()}';

  bool _isFavorite(FoodItem food) {
    final key = _favKey(food.description, food.brandName);
    return _optimistic[key] ?? _favoriteIds.containsKey(key);
  }

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _favoritesSub = _firestoreService.streamFavoriteFoods(uid).listen((favs) {
      if (!mounted) return;
      setState(() {
        _favoriteList = favs;
        _favoriteIds = {
          for (final f in favs) _favKey(f.description, f.brandName): f.id,
        };
        _optimistic.clear();
      });
    }, onError: (_) {});
    _recipesSub = _firestoreService.streamRecipes(uid).listen((r) {
      if (mounted) setState(() => _recipes = r);
    }, onError: (_) {});
    _savedMealsSub = _firestoreService.streamSavedMeals(uid).listen((m) {
      if (mounted) setState(() => _savedMeals = m);
    }, onError: (_) {});
  }

  // Search-as-you-type: each keystroke restarts a short timer, and the
  // search only fires once typing pauses — so you see results appear as you
  // type without sending a request for every single letter.
  Timer? _debounce;

  void _onQueryChanged(String text) {
    // Favorites / Custom filter locally, so they update on every keystroke.
    if (_tab != _SearchTab.all) setState(() {});
    _debounce?.cancel();
    final query = text.trim();
    if (query.isEmpty) {
      // Cleared the box: back to the hint screen.
      setState(() {
        _query = '';
        _resultsFuture = null;
      });
      return;
    }
    // One letter matches far too much to be useful (and wastes a request).
    if (query.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  void _search() {
    _debounce?.cancel();
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    // Must be a block body, not `setState(() => _resultsFuture = ...)` —
    // that arrow form evaluates to the assignment's value, which here is
    // the Future itself, and setState explicitly rejects a callback that
    // returns a Future (it needs a synchronous void callback). That was
    // the actual bug: the tap/Enter were reaching this method the whole
    // time, but setState threw before the screen ever got the new Future
    // to build a FutureBuilder from, so nothing visibly changed.
    setState(() {
      _query = query.toLowerCase();
      _resultsFuture = _usdaService.searchFoods(query);
    });
  }

  Future<void> _logFood(FoodItem food, double grams) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final log = NutritionLog.fromFood(
        food: food,
        grams: grams,
        meal: widget.meal,
        date: widget.date,
      );
      await _firestoreService.addNutritionLog(uid, log);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('Could not save: $e')),
        );
      }
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (code == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    FoodItem? food;
    String? error;
    try {
      food = await _offService.lookupBarcode(code);
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss the loading dialog

    if (food == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error != null
                ? 'Barcode lookup failed: $error'
                : "Couldn't find that barcode — try searching by name instead.",
          ),
        ),
      );
      return;
    }
    _openQuantitySheet(food);
  }

  /// Tapping the star toggles: fills in (purple) and saves the food as a
  /// favorite, or — if it's already one — empties it and removes it.
  Future<void> _toggleFavorite(FoodItem food) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final key = _favKey(food.description, food.brandName);
    final wasFavorite = _isFavorite(food);
    final existingId = _favoriteIds[key];
    // Un-favoriting needs the saved document's id; if the stream hasn't
    // delivered it yet (a tap right after favoriting) ignore the tap.
    if (wasFavorite && existingId == null) return;

    setState(() => _optimistic[key] = !wasFavorite);
    try {
      if (wasFavorite) {
        await _firestoreService.deleteFavoriteFood(uid, existingId!);
      } else {
        await _firestoreService.addFavoriteFood(uid, FavoriteFood.fromFood(food));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _optimistic.remove(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('Could not update favorite: $e')),
        );
      }
    }
  }

  Future<void> _openRecipeSheet(Recipe recipe) async {
    final servings = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipeServingsSheet(recipe: recipe, meal: widget.meal),
    );
    if (servings == null || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await _firestoreService.addNutritionLog(
        uid,
        NutritionLog.fromRecipe(
          recipe: recipe,
          servingsEaten: servings,
          meal: widget.meal,
          date: widget.date,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('Could not save: $e')),
        );
      }
    }
  }

  Future<void> _openSavedMealSheet(SavedMeal meal) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SavedMealConfirmSheet(savedMeal: meal, meal: widget.meal),
    );
    if (confirmed != true || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      for (final item in meal.items) {
        await _firestoreService.addNutritionLog(
          uid,
          NutritionLog.fromComponent(
            component: item,
            meal: widget.meal,
            date: widget.date,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('Could not save: $e')),
        );
      }
    }
  }

  /// Rows for your own recipes / saved meals whose name contains [query]
  /// (defaults to the current search text). With [allWhenEmpty] an empty
  /// query lists everything — used by the Custom tab.
  List<Widget> _myMatches(AppColors colors,
      {String? query, bool allWhenEmpty = false}) {
    final q = (query ?? _query).trim().toLowerCase();
    if (q.isEmpty && !allWhenEmpty) return [];
    final rows = <Widget>[];
    for (final r in _recipes) {
      if (!r.name.toLowerCase().contains(q)) continue;
      rows.add(_ResultRow(
        colors: colors,
        title: r.name,
        subtitle: '1 serving · ${r.perServingCalories.round()} kcal',
        sourceLabel: 'Recipe',
        sourceIsMine: true,
        onTap: () => _openRecipeSheet(r),
      ));
    }
    for (final m in _savedMeals) {
      if (!m.name.toLowerCase().contains(q)) continue;
      rows.add(_ResultRow(
        colors: colors,
        title: m.name,
        subtitle:
            '${m.items.length} item${m.items.length == 1 ? '' : 's'} · ${m.totalCalories.round()} kcal',
        sourceLabel: 'Meal',
        sourceIsMine: true,
        onTap: () => _openSavedMealSheet(m),
      ));
    }
    return rows;
  }

  _ResultRow _foodRow(AppColors colors, FoodItem food) {
    return _ResultRow(
      colors: colors,
      title: _titleCase(food.description),
      subtitle: _foodSubtitle(food),
      sourceLabel: _sourceLabel(food),
      onTap: () => _openQuantitySheet(food),
      isFavorite: _isFavorite(food),
      onFavorite: () => _toggleFavorite(food),
    );
  }

  void _openQuantitySheet(FoodItem food) {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _QuantitySheet(
        food: food,
        meal: widget.meal,
        colors: colors,
        onConfirm: (grams) {
          Navigator.of(sheetContext).pop();
          _logFood(food, grams);
        },
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _favoritesSub?.cancel();
    _recipesSub?.cancel();
    _savedMealsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, size: 18, color: colors.mutedText),
                        const SizedBox(width: 6),
                        Text(
                          'Add to ${widget.meal.label}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _search(),
                      style: TextStyle(color: colors.ink),
                      decoration: InputDecoration(
                        hintText: 'Search a food…',
                        hintStyle: TextStyle(color: colors.mutedText),
                        prefixIcon: Icon(Icons.search, color: colors.mutedText),
                        // Two icons now, not one — without this the
                        // InputDecorator sizes suffixIcon for a single
                        // icon's worth of space and clips the second one.
                        suffixIconConstraints: const BoxConstraints(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.qr_code_scanner, color: colors.mutedText),
                              tooltip: 'Scan a barcode',
                              onPressed: _scanBarcode,
                            ),
                            IconButton(
                              icon: Icon(Icons.arrow_forward, color: colors.tealDeep),
                              onPressed: _search,
                            ),
                          ],
                        ),
                        // Setting only `border` wasn't enough — the app's
                        // global InputDecorationTheme (main.dart) already
                        // supplies its own non-null enabledBorder/
                        // focusedBorder, and Flutter prefers THOSE over
                        // the local `border` fallback. Overriding all
                        // three explicitly is what actually suppresses
                        // the (purple, on focus) theme border this was
                        // meant to replace with the Container's own.
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildTabBar(colors),
            Expanded(child: _buildResults(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(AppColors colors) {
    Widget chip(_SearchTab tab, String label) {
      final selected = _tab == tab;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _tab = tab),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? colors.tealDeep : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : colors.mutedText,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            chip(_SearchTab.all, 'All'),
            chip(_SearchTab.favorites, 'Favorites'),
            chip(_SearchTab.custom, 'Custom'),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(AppColors colors) {
    if (_tab != _SearchTab.all) return _buildListTab(colors);

    if (_resultsFuture == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Search for a food — try something like "chicken breast" or "oats".',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.mutedText),
          ),
        ),
      );
    }
    return FutureBuilder<List<FoodItem>>(
      future: _resultsFuture,
      builder: (context, snapshot) {
        final mine = _myMatches(colors);
        const listPadding = EdgeInsets.only(bottom: 24);

        // Only show the spinner when there's nothing to show yet — while
        // typing, the previous results stay up until the new ones arrive,
        // instead of flashing.
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          if (mine.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: listPadding,
            children: [
              ...mine,
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          final error = Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              '${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          );
          if (mine.isEmpty) return Center(child: error);
          return ListView(padding: listPadding, children: [...mine, error]);
        }
        final results = snapshot.data ?? [];
        if (results.isEmpty && mine.isEmpty) {
          return Center(
            child: Text('No results.', style: TextStyle(color: colors.mutedText)),
          );
        }
        return ListView(
          padding: listPadding,
          children: [
            ...mine,
            for (final food in results) _foodRow(colors, food),
          ],
        );
      },
    );
  }

  /// The Favorites and Custom tabs: your own saved stuff, listed in full
  /// when the search box is empty and narrowed as you type.
  Widget _buildListTab(AppColors colors) {
    final text = _searchController.text.trim().toLowerCase();
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    const listPadding = EdgeInsets.only(bottom: 24);

    List<Widget> rows;
    String emptyText;
    if (_tab == _SearchTab.favorites) {
      final matches = _favoriteList.where((f) {
        final hay = '${f.description} ${f.brandName ?? ''}'.toLowerCase();
        return words.every(hay.contains);
      }).toList()
        ..sort((a, b) =>
            a.description.toLowerCase().compareTo(b.description.toLowerCase()));
      rows = [for (final f in matches) _foodRow(colors, f.toFoodItem())];
      emptyText = _favoriteList.isEmpty
          ? 'No favorites yet — tap the star on any food to save it here.'
          : 'No favorites match that search.';
    } else {
      rows = _myMatches(colors, query: text, allWhenEmpty: true);
      emptyText = (_recipes.isEmpty && _savedMeals.isEmpty)
          ? 'Recipes and saved meals you create show up here.'
          : 'Nothing you made matches that search.';
    }

    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.mutedText),
          ),
        ),
      );
    }
    return ListView(padding: listPadding, children: rows);
  }
}

// --- Formatting helpers for result rows ---

const _lowerWords = {'and', 'or', 'of', 'with', 'in', 'a', 'an', 'the', 'to', 'for', 'on'};

/// "CHICKEN, BROILERS OR FRYERS, BREAST" -> "Chicken, Broilers or Fryers,
/// Breast" — USDA mixes ALL CAPS and lowercase; Cronometer shows Title Case.
String _titleCase(String input) {
  final words = input.trim().split(RegExp(r'\s+'));
  final out = <String>[];
  for (var i = 0; i < words.length; i++) {
    final raw = words[i];
    if (raw.isEmpty) continue;
    final lower = raw.toLowerCase();
    final bare = lower.replaceAll(RegExp(r'[^a-z]'), '');
    if (i > 0 && _lowerWords.contains(bare) && bare == lower) {
      out.add(lower);
      continue;
    }
    // Capitalize the first letter, leaving a leading "(" etc. alone.
    final idx = lower.indexOf(RegExp(r'[a-z]'));
    if (idx < 0) {
      out.add(lower);
    } else {
      out.add(lower.substring(0, idx) +
          lower[idx].toUpperCase() +
          lower.substring(idx + 1));
    }
  }
  return out.join(' ');
}

/// Where the entry came from, shown on the right of each row.
String _sourceLabel(FoodItem food) {
  final type = food.dataType;
  if (type == null) return 'Saved';
  if (type == 'Branded') return 'Brand';
  return 'USDA';
}

/// "1 cup (140 g) · 231 kcal", with the brand in front for packaged foods.
/// Falls back to a 100 g serving when the database has no serving size.
String _foodSubtitle(FoodItem food) {
  final grams = food.servingSizeGrams ?? 100;
  final gramsText = grams == grams.roundToDouble()
      ? grams.round().toString()
      : grams.toStringAsFixed(1);
  final household = food.householdServing?.trim();
  final serving = (household != null && household.isNotEmpty)
      ? '$household ($gramsText g)'
      : '$gramsText g';
  final kcal = (food.calories * grams / 100).round();
  final parts = <String>[
    if (food.brandName != null && food.brandName!.trim().isNotEmpty)
      _titleCase(food.brandName!),
    serving,
    '$kcal kcal',
  ];
  return parts.join(' · ');
}

/// One flat, compact search result — name, then serving + calories under
/// it, then where it came from on the right (Cronometer-style). Foods get a
/// favorite star; your own recipes / meals show their label in purple.
class _ResultRow extends StatelessWidget {
  final AppColors colors;
  final String title;
  final String subtitle;
  final String sourceLabel;
  final bool sourceIsMine;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  const _ResultRow({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.sourceLabel,
    required this.onTap,
    this.sourceIsMine = false,
    this.isFavorite = false,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 12, onFavorite != null ? 8 : 24, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.mutedText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              sourceLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: sourceIsMine ? colors.purpleDeep : colors.mutedText,
              ),
            ),
            if (onFavorite != null)
              IconButton(
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? colors.purpleDeep : colors.mutedText,
                  size: 22,
                ),
                tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

/// The bottom sheet that opens after tapping a search result — pick an
/// amount, see the scaled macros update live, confirm.
class _QuantitySheet extends StatefulWidget {
  final FoodItem food;
  final Meal meal;
  final AppColors colors;
  final ValueChanged<double> onConfirm;

  const _QuantitySheet({
    required this.food,
    required this.meal,
    required this.colors,
    required this.onConfirm,
  });

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  late final TextEditingController _gramsController;

  @override
  void initState() {
    super.initState();
    final defaultGrams = widget.food.servingSizeGrams ?? 100;
    _gramsController = TextEditingController(
      text: defaultGrams.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final grams = double.tryParse(_gramsController.text) ?? 0;
    final factor = grams / 100;

    Widget macro(String label, double value, String unit, Color accent) {
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(height: 6),
            Text(
              '${(value * factor).round()}$unit',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: colors.mutedText),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.food.description,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Adding to ${widget.meal.label}',
              style: TextStyle(fontSize: 13, color: colors.mutedText),
            ),
            const SizedBox(height: 20),
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
                // Same shared bubble as the workout log's weight/reps
                // fields (NumberBubble) — it reads as "raised" because
                // its fill (colors.background) is darker than whatever
                // it sits on. This sheet's own root IS colors.background
                // though, so the bubble is wrapped in a colors.surface
                // backing first to recreate the same darker-bubble-on-
                // lighter-card contrast the workout screen has for free.
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: NumberBubble(
                    width: 100,
                    height: 52,
                    controller: _gramsController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    suffixText: ' g',
                  ),
                ),
              ],
            ),
            if (widget.food.householdServing != null) ...[
              const SizedBox(height: 4),
              Text(
                'Typical serving: ${widget.food.householdServing}',
                style: TextStyle(fontSize: 12, color: colors.mutedText),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: colors.lilacBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  macro('kcal', widget.food.calories, '', colors.tealDeep),
                  macro('protein', widget.food.protein, 'g', colors.purpleDeep),
                  macro('carbs', widget.food.carbs, 'g', colors.lilacText),
                  macro('fat', widget.food.fat, 'g', colors.mutedText),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                  onTap: grams > 0 ? () => widget.onConfirm(grams) : null,
                  child: Ink(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.tealVivid, colors.tealDeep],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Add to ${widget.meal.label}',
                        style: const TextStyle(
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
    );
  }
}

/// Shared look for the bottom sheets below: rounded top, drag handle.
class _SheetFrame extends StatelessWidget {
  final AppColors colors;
  final List<Widget> children;
  const _SheetFrame({required this.colors, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AppColors colors;
  const _PrimaryButton({required this.label, required this.onTap, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        child: InkWell(
          onTap: onTap,
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [colors.tealVivid, colors.tealDeep]),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pick how many servings of one of your recipes to log.
class _RecipeServingsSheet extends StatefulWidget {
  final Recipe recipe;
  final Meal meal;
  const _RecipeServingsSheet({required this.recipe, required this.meal});

  @override
  State<_RecipeServingsSheet> createState() => _RecipeServingsSheetState();
}

class _RecipeServingsSheetState extends State<_RecipeServingsSheet> {
  final _controller = TextEditingController(text: '1');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final r = widget.recipe;
    final servings = double.tryParse(_controller.text) ?? 0;

    Widget macro(String label, double perServing, String unit, Color accent) {
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(height: 6),
            Text(
              '${(perServing * servings).round()}$unit',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colors.ink),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: colors.mutedText)),
          ],
        ),
      );
    }

    return _SheetFrame(
      colors: colors,
      children: [
        Text(
          r.name,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.ink),
        ),
        const SizedBox(height: 4),
        Text(
          'Your recipe · adding to ${widget.meal.label}',
          style: TextStyle(fontSize: 13, color: colors.mutedText),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'Servings',
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
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: colors.lilacBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              macro('kcal', r.perServingCalories, '', colors.tealDeep),
              macro('protein', r.perServingProtein, 'g', colors.purpleDeep),
              macro('carbs', r.perServingCarbs, 'g', colors.lilacText),
              macro('fat', r.perServingFat, 'g', colors.mutedText),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          colors: colors,
          label: 'Add to ${widget.meal.label}',
          onTap: servings > 0 ? () => Navigator.of(context).pop(servings) : null,
        ),
      ],
    );
  }
}

/// Confirm adding one of your saved meals — lists what's in it, since
/// logging it drops every item into the day at once.
class _SavedMealConfirmSheet extends StatelessWidget {
  final SavedMeal savedMeal;
  final Meal meal;
  const _SavedMealConfirmSheet({required this.savedMeal, required this.meal});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _SheetFrame(
      colors: colors,
      children: [
        Text(
          savedMeal.name,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.ink),
        ),
        const SizedBox(height: 4),
        Text(
          'Your meal · ${savedMeal.totalCalories.round()} kcal · adding to ${meal.label}',
          style: TextStyle(fontSize: 13, color: colors.mutedText),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final item in savedMeal.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: colors.ink),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${item.grams.round()}g',
                        style: TextStyle(fontSize: 13, color: colors.mutedText),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          colors: colors,
          label: 'Add to ${meal.label}',
          onTap: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

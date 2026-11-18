import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/brand_foods.dart';
import '../models/food_item.dart';
import 'open_food_facts_service.dart';

/// Wraps the USDA FoodData Central search API — the free database Compound
/// uses to look up real nutrition data instead of asking you to type in
/// calories/macros by hand for every food.
///
/// Uses Alexia's own free FoodData Central key (1,000 requests/hour —
/// plenty for real day-to-day use), not the shared DEMO_KEY this started
/// with. If this repo ever goes public, move this to an untracked config
/// file instead of leaving a real key committed in source.
class UsdaFoodService {
  final _off = OpenFoodFactsService();
  static const _apiKey = 'dpFd8thBLQ9WMBGgRd7D8DbLcJRMcNHBTk7CjLDP';
  static const _baseUrl = 'https://api.nal.usda.gov/fdc/v1';

  /// Searches USDA's database the way Cronometer's feels: plain, generic
  /// foods first ("Chicken breast, roasted"), store brands and restaurant
  /// items only after.
  ///
  /// Two searches run side by side instead of one mixed one. A single mixed
  /// query gets crowded out by Branded entries (there are hundreds of
  /// thousands of them, and many match any short query), so the generic
  /// entry might not even be in the first page. Asking for them separately
  /// guarantees both groups show up, generic on top:
  ///   - generic: Foundation + SR Legacy (USDA's lab-analyzed data) plus
  ///     Survey (FNDDS), the home-prepared/"as eaten" entries (baked, fried,
  ///     with or without skin, ...)
  ///   - branded: packaged and restaurant products, capped so they can't
  ///     bury the generic list.
  Future<List<FoodItem>> searchFoods(String query) async {
    // A failure in one group must not hide the other (e.g. brands like
    // "IsoGold" only exist in the branded group), so each group swallows its
    // own error; it only surfaces if EVERYTHING failed.
    Object? firstError;
    Future<List<FoodItem>> safe(Future<List<FoodItem>> f) =>
        f.catchError((Object e) {
          firstError ??= e;
          return <FoodItem>[];
        });

    final results = await Future.wait([
      safe(_generic(query)),
      safe(_branded(query)),
      // Open Food Facts (never throws): gym brands and supplements USDA
      // doesn't carry. Its entries whose name or brand contains every word
      // typed come first, so a brand search like "isogold" leads with it.
      _off.searchProducts(query).then((items) => _onlyMatchingAllWords(items, query)),
    ]);
    final builtIn = matchBrandFoods(query);
    if (results[0].isEmpty &&
        results[1].isEmpty &&
        results[2].isEmpty &&
        builtIn.isEmpty &&
        firstError != null) {
      throw firstError!;
    }
    final generic = _rankGeneric(results[0], query);
    final brandWords = _words(query);
    final offMatches = results[2].where((f) {
      final text = '${f.description} ${f.brandName ?? ''}'.toLowerCase();
      return brandWords.every(text.contains);
    }).take(20).toList();
    return [...generic, ...builtIn, ...results[1], ...offMatches];
  }

  // One request per data type, each failing independently.
  static const _genericTypes = ['Survey (FNDDS)', 'Foundation', 'SR Legacy'];

  Future<List<FoodItem>> _generic(String query) async {
    Object? firstError;
    final lists = await Future.wait(
      _genericTypes.map(
        (type) => _search(query, dataType: type, pageSize: 30).catchError((Object e) {
          firstError ??= e;
          return <FoodItem>[];
        }),
      ),
    );
    final items = [for (final list in lists) ...list];
    if (items.isEmpty && firstError != null) throw firstError!;
    return _onlyMatchingAllWords(items, query);
  }

  Future<List<FoodItem>> _branded(String query) async {
    final items = await _search(query, dataType: 'Branded', pageSize: 50);
    return _onlyMatchingAllWords(items, query).take(15).toList();
  }

  /// Uses USDA's POST form of the search (JSON body) rather than a long
  /// query string — data types like "Survey (FNDDS)" contain spaces and
  /// parentheses, and putting them in the URL produced "400 Bad Request"
  /// from USDA's web server. In a JSON body there is nothing to encode.
  Future<List<FoodItem>> _search(
    String query, {
    required String dataType,
    required int pageSize,
  }) async {
    final uri = Uri.parse('$_baseUrl/foods/search?api_key=$_apiKey');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'query': query,
        'dataType': [dataType],
        'pageSize': pageSize,
      }),
    );

    if (response.statusCode == 429) {
      throw Exception(
        'USDA rate limit hit (1,000 requests/hour) — try again in a bit.',
      );
    }
    if (response.statusCode != 200) {
      final body = response.body;
      final detail = body.length > 160 ? body.substring(0, 160) : body;
      throw Exception(
          'Food search failed (HTTP ${response.statusCode}, $dataType) $detail');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final foods = (body['foods'] as List<dynamic>? ?? []);
    return foods
        .map((f) => FoodItem.fromUsdaJson(f as Map<String, dynamic>))
        .toList();
  }

  List<String> _words(String query) => query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  /// USDA's search matches foods containing ANY of your words, so
  /// "chicken breast" also returns things that are merely chicken or merely
  /// breast. Keep only the foods whose name (or brand) has every word you
  /// typed — but if that leaves nothing (an unusual query), fall back to
  /// USDA's full list instead of showing an empty screen.
  List<FoodItem> _onlyMatchingAllWords(List<FoodItem> items, String query) {
    final words = _words(query);
    if (words.isEmpty) return items;
    final matching = items.where((f) {
      final text = '${f.description} ${f.brandName ?? ''}'.toLowerCase();
      return words.every(text.contains);
    }).toList();
    return matching.isEmpty ? items : matching;
  }

  /// USDA's own ranking is plain text relevance, so for "chicken breast" the
  /// entry literally named "Chicken, broilers or fryers, breast, meat only,
  /// raw" can outrank a plain "Chicken breast, roasted". USDA names put the
  /// food itself before the first comma ("Chicken breast, ..."), so entries
  /// whose *name part* already contains every word you typed are moved to the
  /// top, keeping USDA's order within each group.
  List<FoodItem> _rankGeneric(List<FoodItem> items, String query) {
    final words = _words(query);
    if (words.isEmpty) return items;

    bool nameMatches(FoodItem f) {
      final name = f.description.toLowerCase().split(',').first;
      return words.every(name.contains);
    }

    final strong = items.where(nameMatches).toList();
    final rest = items.where((f) => !nameMatches(f)).toList();
    return [...strong, ...rest];
  }
}

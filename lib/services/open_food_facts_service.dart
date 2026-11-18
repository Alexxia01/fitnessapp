import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/food_item.dart';

/// Barcode lookups go through Open Food Facts instead of USDA — USDA's
/// search API ranks by text relevance and has no real "look up by
/// GTIN/UPC" endpoint, so scanning a barcode and shoving the digits in as a
/// text query is unreliable. Open Food Facts is built around barcodes
/// specifically (that's literally the primary key of their database), is
/// free, and needs no API key.
class OpenFoodFactsService {
  static const _baseUrl = 'https://world.openfoodfacts.org/api/v2/product';

  /// Returns null if the barcode isn't in Open Food Facts' database, or
  /// what's there doesn't have a usable name/nutrition panel.
  Future<FoodItem?> lookupBarcode(String barcode) async {
    final uri = Uri.parse(
      '$_baseUrl/$barcode.json'
      '?fields=product_name,brands,nutriments,serving_size,serving_quantity',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != 1) return null; // not found in OFF's database

    final product = body['product'] as Map<String, dynamic>?;
    if (product == null) return null;
    return _toFoodItem(product);
  }

  /// Free-text product search by name or brand ("isogold", "elev8") — the
  /// gym-brand supplements and packaged foods that USDA's branded list
  /// often lacks. Community-contributed, so coverage varies by product.
  /// Returns an empty list on any failure; callers treat this as a bonus
  /// source, never a reason to fail the whole search.
  Future<List<FoodItem>> searchProducts(String query, {int pageSize = 24}) async {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/cgi/search.pl'
      '?search_terms=${Uri.encodeComponent(query)}'
      '&search_simple=1&action=process&json=1&page_size=$pageSize'
      '&fields=product_name,brands,nutriments,serving_size,serving_quantity',
    );
    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'Compound/1.0 (personal fitness app)',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint('OFF search "$query": HTTP ${response.statusCode}');
        return [];
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final products = body['products'] as List<dynamic>? ?? [];
      debugPrint('OFF search "$query": ${products.length} products returned');
      return [
        for (final p in products)
          if (_toFoodItem(p as Map<String, dynamic>) case final item?) item,
      ];
    } catch (e) {
      debugPrint('OFF search "$query" failed: $e');
      return [];
    }
  }

  FoodItem? _toFoodItem(Map<String, dynamic> product) {
    final nutriments = product['nutriments'] as Map<String, dynamic>?;
    if (nutriments == null) return null;

    final name = (product['product_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    // Entries with no calorie data at all are unusable for logging.
    if (nutriments['energy-kcal_100g'] is! num) return null;

    double value(String key) {
      final v = nutriments[key];
      return (v is num) ? v.toDouble() : 0;
    }

    final brand = (product['brands'] as String?)?.split(',').first.trim();
    return FoodItem(
      fdcId: -1,
      description: name,
      brandName: (brand == null || brand.isEmpty) ? null : brand,
      // OFF reports these "_100g" fields per 100g already, same convention
      // as USDA, so no extra scaling needed here.
      calories: value('energy-kcal_100g'),
      protein: value('proteins_100g'),
      carbs: value('carbohydrates_100g'),
      fat: value('fat_100g'),
      fiber: value('fiber_100g'),
      sugar: value('sugars_100g'),
      // OFF reports sodium in grams per 100g, not mg — this app's
      // convention (matching USDA) is mg, so convert.
      sodiumMg: value('sodium_100g') * 1000,
      cholesterolMg: value('cholesterol_100g') * 1000,
      servingSizeGrams: (product['serving_quantity'] is num)
          ? (product['serving_quantity'] as num).toDouble()
          : (double.tryParse('${product['serving_quantity'] ?? ''}')),
      householdServing: product['serving_size'] as String?,
      dataType: 'Branded',
    );
  }
}

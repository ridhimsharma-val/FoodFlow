import 'package:flutter/material.dart';

class AiExtractedFood {
  final String foodName;
  final String category;
  final int quantityServings;
  final String dietaryType; // 'Pure Veg' or 'Non-Veg'
  final TimeOfDay? preparedAt;
  final TimeOfDay? bestBefore;
  final String specialInstructions;

  const AiExtractedFood({
    required this.foodName,
    required this.category,
    required this.quantityServings,
    required this.dietaryType,
    this.preparedAt,
    this.bestBefore,
    this.specialInstructions = '',
  });

  String get preparedAtFormatted {
    if (preparedAt == null) return 'Current Time';
    final hour = preparedAt!.hourOfPeriod == 0 ? 12 : preparedAt!.hourOfPeriod;
    final period = preparedAt!.period == DayPeriod.am ? 'AM' : 'PM';
    final min = preparedAt!.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  String get bestBeforeFormatted {
    if (bestBefore == null) return 'In 4 hours';
    final hour = bestBefore!.hourOfPeriod == 0 ? 12 : bestBefore!.hourOfPeriod;
    final period = bestBefore!.period == DayPeriod.am ? 'AM' : 'PM';
    final min = bestBefore!.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }
}

abstract class AiFoodExtractorBackend {
  Future<AiExtractedFood?> extractDetails(String prompt);
}

/// Default Rule-based Natural Language Extractor
/// (Pluggable: Can be replaced with OpenAI/Gemini client when backend endpoint is configured)
class RuleBasedAiExtractor implements AiFoodExtractorBackend {
  @override
  Future<AiExtractedFood?> extractDetails(String prompt) async {
    final clean = prompt.trim();
    if (clean.isEmpty) return null;

    // 1. Quantity extraction (e.g., "40 packets", "50 servings", "25 meals", "100 boxes", "30 portions")
    int quantity = 25;
    final qtyMatch = RegExp(
      r'(\d+)\s*(?:packets|servings|meals|boxes|portions|plates|kg|people|pax)?',
      caseSensitive: false,
    ).firstMatch(clean);
    if (qtyMatch != null) {
      final parsed = int.tryParse(qtyMatch.group(1) ?? '');
      if (parsed != null && parsed > 0) {
        quantity = parsed;
      }
    }

    // 2. Dietary classification (Veg vs Non-Veg)
    String dietary = 'Pure Veg';
    final lower = clean.toLowerCase();
    if (lower.contains('chicken') ||
        lower.contains('mutton') ||
        lower.contains('fish') ||
        lower.contains('egg') ||
        lower.contains('meat') ||
        lower.contains('non veg') ||
        lower.contains('non-veg') ||
        lower.contains('prawn')) {
      dietary = 'Non-Veg';
    } else if (lower.contains('veg') ||
        lower.contains('paneer') ||
        lower.contains('dal') ||
        lower.contains('rice') ||
        lower.contains('roti') ||
        lower.contains('bread') ||
        lower.contains('sambar') ||
        lower.contains('salad')) {
      dietary = 'Pure Veg';
    }

    // 3. Category classification
    String category = 'Cooked Meal';
    if (lower.contains('bread') ||
        lower.contains('cake') ||
        lower.contains('pastry') ||
        lower.contains('croissant') ||
        lower.contains('bun') ||
        lower.contains('bakery')) {
      category = 'Bakery & Bread';
    } else if (lower.contains('fruit') ||
        lower.contains('vegetable') ||
        lower.contains('salad') ||
        lower.contains('tomato') ||
        lower.contains('apple')) {
      category = 'Fresh Produce';
    } else if (lower.contains('biscuit') ||
        lower.contains('packet') ||
        lower.contains('canned') ||
        lower.contains('juice') ||
        lower.contains('tetra')) {
      category = 'Packaged Goods';
    } else if (lower.contains('rice') ||
        lower.contains('wheat') ||
        lower.contains('flour') ||
        lower.contains('grain') ||
        lower.contains('pulses')) {
      category = 'Raw Grains & Rations';
    }

    // 4. Food Name extraction
    String foodName = 'Surplus Meals';
    if (lower.contains('rice and dal') || lower.contains('rice & dal') || lower.contains('dal rice')) {
      foodName = 'Rice & Dal';
    } else if (lower.contains('paneer') && lower.contains('roti')) {
      foodName = 'Paneer Butter Masala & Rotis';
    } else if (lower.contains('roti and sabzi') || lower.contains('roti & sabzi') || lower.contains('chapati')) {
      foodName = 'Roti & Sabzi';
    } else if (lower.contains('biryani')) {
      foodName = dietary == 'Non-Veg' ? 'Chicken Biryani' : 'Veg Dum Biryani';
    } else if (lower.contains('bread') || lower.contains('loaf')) {
      foodName = 'Artisan Bread Loaves';
    } else if (lower.contains('sandwich')) {
      foodName = 'Assorted Sandwiches';
    } else if (lower.contains('dosa') || lower.contains('idli')) {
      foodName = 'Idli & Vada Meal Boxes';
    } else {
      // Try to isolate food keywords from the sentence
      final afterHave = RegExp(r'(?:have|got|prepared|leftover|cooked)\s+(?:\d+\s+(?:packets|servings|meals|boxes|plates)?\s*(?:of)?\s*)?([A-Za-z\s&]+?)(?:\s+(?:prepared|made|at|before|pickup|ready)|$)', caseSensitive: false)
          .firstMatch(clean);
      if (afterHave != null && afterHave.group(1) != null && afterHave.group(1)!.trim().isNotEmpty) {
        final extracted = afterHave.group(1)!.trim();
        if (extracted.split(' ').length <= 5) {
          foodName = _capitalize(extracted);
        }
      }
    }

    // 5. Timings extraction
    TimeOfDay preparedAt = const TimeOfDay(hour: 18, minute: 0); // 6:00 PM
    TimeOfDay bestBefore = const TimeOfDay(hour: 21, minute: 0); // 9:00 PM

    final prepMatch = RegExp(r'(?:prepared|cooked|made|ready)\s*(?:at)?\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false)
        .firstMatch(clean);
    if (prepMatch != null) {
      int h = int.tryParse(prepMatch.group(1) ?? '18') ?? 18;
      final m = int.tryParse(prepMatch.group(2) ?? '0') ?? 0;
      final p = prepMatch.group(3)?.toLowerCase();
      if (p == 'pm' && h < 12) h += 12;
      if (p == 'am' && h == 12) h = 0;
      if (p == null && h < 9) h += 12; // assume evening for typical 6 or 7
      preparedAt = TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    }

    final beforeMatch = RegExp(r'(?:before|until|by|pickup before)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false)
        .firstMatch(clean);
    if (beforeMatch != null) {
      int h = int.tryParse(beforeMatch.group(1) ?? '21') ?? 21;
      final m = int.tryParse(beforeMatch.group(2) ?? '0') ?? 0;
      final p = beforeMatch.group(3)?.toLowerCase();
      if (p == 'pm' && h < 12) h += 12;
      if (p == 'am' && h == 12) h = 0;
      if (p == null && h <= 11) {
        // If preparedAt is in the afternoon/evening (>= 12), then "before 9" means 9 PM (21:00)
        if (preparedAt.hour >= 12 || h <= 6) {
          h += 12;
        }
      }
      bestBefore = TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    } else {
      // Default best before to 3 hours after preparedAt
      final newHour = (preparedAt.hour + 3) % 24;
      bestBefore = TimeOfDay(hour: newHour, minute: preparedAt.minute);
    }

    return AiExtractedFood(
      foodName: foodName,
      category: category,
      quantityServings: quantity,
      dietaryType: dietary,
      preparedAt: preparedAt,
      bestBefore: bestBefore,
      specialInstructions: 'Handle with care. Packaged food-grade containers.',
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ');
  }
}

class AiFoodAssistantService {
  static AiFoodExtractorBackend backend = RuleBasedAiExtractor();

  static Future<AiExtractedFood?> extractFromText(String prompt) {
    return backend.extractDetails(prompt);
  }
}

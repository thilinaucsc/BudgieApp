import 'package:flutter/material.dart';
import 'expense_category.dart';

// Icons are stored by key because release builds only bundle const icons.
const Map<String, IconData> categoryIconChoices = {
  'pets': Icons.pets,
  'home': Icons.home_outlined,
  'car': Icons.directions_car,
  'fuel': Icons.local_gas_station,
  'phone': Icons.phone_android,
  'wifi': Icons.wifi,
  'gift': Icons.card_giftcard,
  'child': Icons.child_friendly,
  'fitness': Icons.fitness_center,
  'travel': Icons.flight,
  'coffee': Icons.local_cafe,
  'book': Icons.menu_book,
  'music': Icons.music_note,
  'game': Icons.sports_esports,
  'tools': Icons.build_outlined,
  'charity': Icons.volunteer_activism,
  'work': Icons.work_outline,
  'star': Icons.star_outline,
};

const List<Color> categoryColorChoices = [
  Color(0xFFE53935),
  Color(0xFFD81B60),
  Color(0xFF8E24AA),
  Color(0xFF3949AB),
  Color(0xFF1E88E5),
  Color(0xFF00ACC1),
  Color(0xFF00897B),
  Color(0xFF43A047),
  Color(0xFFC0A000),
  Color(0xFFFB8C00),
  Color(0xFF6D4C41),
  Color(0xFF546E7A),
];

class CustomCategory {
  final int? id;
  final String name;
  final String iconKey;
  final int colorValue;

  const CustomCategory({
    this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon_key': iconKey,
        'color': colorValue,
      };

  factory CustomCategory.fromMap(Map<String, dynamic> m) => CustomCategory(
        id: m['id'] as int?,
        name: m['name'] as String,
        iconKey: m['icon_key'] as String,
        colorValue: m['color'] as int,
      );

  ExpenseCategory toCategory() => ExpenseCategory(
        name,
        categoryIconChoices[iconKey] ?? Icons.star_outline,
        Color(colorValue),
      );
}

/// Why [name] can't be used, or null when it is fine. [current] is the name
/// being edited, which may keep its own spelling or change its capitals.
String? categoryNameError(String name, {String? current}) {
  final wanted = name.trim().toLowerCase();
  if (wanted.isEmpty) return 'Enter a name';
  final taken = categories.any((c) =>
      c.name.toLowerCase() == wanted && c.name != current);
  return taken ? 'A category with this name already exists' : null;
}

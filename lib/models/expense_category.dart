import 'package:flutter/material.dart';

class ExpenseCategory {
  final String name;
  final IconData icon;
  final Color color;
  const ExpenseCategory(this.name, this.icon, this.color);
}

const String fallbackCategoryName = 'Other';

const List<ExpenseCategory> builtInCategories = [
  ExpenseCategory('Food', Icons.restaurant, Colors.orange),
  ExpenseCategory('Groceries', Icons.local_grocery_store, Color(0xFF66BB6A)),
  ExpenseCategory('Dining Out', Icons.restaurant_menu, Colors.deepOrange),
  ExpenseCategory('Transport', Icons.directions_bus, Colors.blue),
  ExpenseCategory('Bills', Icons.receipt_long, Colors.red),
  ExpenseCategory('Shopping', Icons.shopping_bag, Colors.purple),
  ExpenseCategory('Health', Icons.local_hospital, Colors.green),
  ExpenseCategory('Entertainment', Icons.movie, Colors.yellow),
  ExpenseCategory('Education', Icons.school, Colors.indigo),
  ExpenseCategory('Personal Care', Icons.spa, Color(0xFFEC407A)),
  ExpenseCategory('Savings', Icons.savings, Colors.teal),
  ExpenseCategory(fallbackCategoryName, Icons.more_horiz, Colors.grey),
];

List<ExpenseCategory> _customCategories = const [];

/// Called by [DatabaseHelper] whenever the saved custom categories change.
void setCustomCategories(List<ExpenseCategory> custom) =>
    _customCategories = List.unmodifiable(custom);

/// Built-in categories followed by the user's own, with Other kept last.
List<ExpenseCategory> get categories => [
      ...builtInCategories.take(builtInCategories.length - 1),
      ..._customCategories,
      builtInCategories.last,
    ];

ExpenseCategory categoryByName(String name) {
  final all = categories;
  return all.firstWhere((c) => c.name == name, orElse: () => all.last);
}

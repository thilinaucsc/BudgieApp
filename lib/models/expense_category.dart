import 'package:flutter/material.dart';

class ExpenseCategory {
  final String name;
  final IconData icon;
  final Color color;
  const ExpenseCategory(this.name, this.icon, this.color);
}

// Version 1 uses a fixed list. Add or change categories here.
const List<ExpenseCategory> categories = [
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
  ExpenseCategory('Other', Icons.more_horiz, Colors.grey),
];

ExpenseCategory categoryByName(String name) =>
    categories.firstWhere((c) => c.name == name, orElse: () => categories.last);

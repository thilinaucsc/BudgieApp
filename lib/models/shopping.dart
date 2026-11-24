import 'household_item.dart';

/// Shows whole numbers without a decimal point: 2 kg, 1.5 L.
String formatQuantity(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

/// How much to buy to get back to twice the minimum, so the item does not
/// run low again straight away. Always at least 1.
double suggestedPurchase(HouseholdItem item) {
  final need = item.minQuantity * 2 - item.quantity;
  if (need <= 0) return 1;
  return (need * 10).ceil() / 10;
}

/// A plain text list to share with whoever is going to the shop.
String shoppingListText(List<HouseholdItem> items) {
  final lines = [
    for (final item in items)
      '• ${item.name}: ${formatQuantity(suggestedPurchase(item))} ${item.unit}',
  ];
  return ['Shopping list', ...lines].join('\n');
}

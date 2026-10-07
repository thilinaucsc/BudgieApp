class HouseholdItem {
  int? id;
  String name;
  double quantity;
  double minQuantity;
  String unit;

  HouseholdItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.minQuantity,
    required this.unit,
  });

  bool get isLow => quantity <= minQuantity;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'min_quantity': minQuantity,
        'unit': unit,
      };

  factory HouseholdItem.fromMap(Map<String, dynamic> m) => HouseholdItem(
        id: m['id'] as int?,
        name: m['name'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        minQuantity: (m['min_quantity'] as num).toDouble(),
        unit: m['unit'] as String,
      );
}

class SplitterTrip {
  final int? id;
  final String name;
  final DateTime createdAt;

  SplitterTrip({
    this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
      };

  factory SplitterTrip.fromMap(Map<String, dynamic> m) => SplitterTrip(
        id: m['id'] as int?,
        name: m['name'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

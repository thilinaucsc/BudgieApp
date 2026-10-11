class SplitterParticipant {
  final int? id;
  final int tripId;
  final String name;

  SplitterParticipant({
    this.id,
    required this.tripId,
    required this.name,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'name': name,
      };

  factory SplitterParticipant.fromMap(Map<String, dynamic> m) =>
      SplitterParticipant(
        id: m['id'] as int?,
        tripId: m['trip_id'] as int,
        name: m['name'] as String,
      );
}

class DayNote {
  final int id;
  final DateTime date;
  final String body;
  final String updatedAt;

  const DayNote({
    required this.id,
    required this.date,
    required this.body,
    required this.updatedAt,
  });

  factory DayNote.fromJson(Map<String, dynamic> j) => DayNote(
        id: j['id'] as int,
        date: DateTime.parse(j['date'] as String),
        body: j['body'] as String,
        updatedAt: j['updatedAt'] as String,
      );
}

class NamedRef {
  final int id;
  final String name;

  const NamedRef({required this.id, required this.name});

  factory NamedRef.fromJson(Map<String, dynamic> j) =>
      NamedRef(id: j['id'] as int, name: j['name'] as String);
}

class RaspisanieEntry {
  final DateTime date;
  final int subjectNumber;
  final int? subgroup;
  final String classroom;
  final NamedRef group;
  final NamedRef teacher;
  final NamedRef subject;
  // True when the server detected this slot deviates from the shablon
  // template — a teacher-modified lesson. Defaults to false so older
  // server versions that don't return the field degrade gracefully.
  final bool isOverride;

  const RaspisanieEntry({
    required this.date,
    required this.subjectNumber,
    required this.subgroup,
    required this.classroom,
    required this.group,
    required this.teacher,
    required this.subject,
    this.isOverride = false,
  });

  factory RaspisanieEntry.fromJson(Map<String, dynamic> j) => RaspisanieEntry(
        date: DateTime.parse(j['date'] as String),
        subjectNumber: j['subjectNumber'] as int,
        subgroup: j['subgroup'] as int?,
        classroom: j['classroom'] as String,
        group: NamedRef.fromJson(j['groupBy'] as Map<String, dynamic>),
        teacher: NamedRef.fromJson(j['teacherBy'] as Map<String, dynamic>),
        subject: NamedRef.fromJson(j['subjectBy'] as Map<String, dynamic>),
        isOverride: (j['isOverride'] as bool?) ?? false,
      );
}

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/api/raspisanie_repository.dart';
import 'package:ncti_schedule_client/models/raspisanie.dart';

/// Item 1 of 1.2.10: the JSON→RaspisanieEntry parse moves off the main
/// isolate via [compute]. These tests pin the contract that lets that
/// happen — the parser must be a top-level function and produce the same
/// result as the prior in-line .map(...).toList() form.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> sampleEntry({
    required String date,
    required int subjectNumber,
    int? subgroup,
    String classroom = '101',
    int groupId = 1,
    String groupName = 'TC-21',
    int teacherId = 11,
    String teacherName = 'Petrov',
    int subjectId = 100,
    String subjectName = 'Math',
    bool? isOverride,
  }) =>
      {
        'date': date,
        'subjectNumber': subjectNumber,
        'subgroup': subgroup,
        'classroom': classroom,
        'groupBy': {'id': groupId, 'name': groupName},
        'teacherBy': {'id': teacherId, 'name': teacherName},
        'subjectBy': {'id': subjectId, 'name': subjectName},
        if (isOverride != null) 'isOverride': isOverride,
      };

  test('parseRaspisanieList is top-level (compute-compatible)', () async {
    // The Function `is` check confirms the symbol is callable as a top-level
    // (i.e., not bound to an instance). compute() refuses closures and
    // instance methods, so this guards against accidental refactors.
    expect(
      parseRaspisanieList,
      isA<List<RaspisanieEntry> Function(List<Map<String, dynamic>>)>(),
    );
    // And it actually round-trips through compute() without a serialization
    // error — the strongest possible check.
    final raw = <Map<String, dynamic>>[
      sampleEntry(date: '2026-04-27', subjectNumber: 1, subgroup: 1),
      sampleEntry(date: '2026-04-27', subjectNumber: 2),
    ];
    final out = await compute(parseRaspisanieList, raw);
    expect(out, hasLength(2));
    expect(out.first.subjectNumber, 1);
    expect(out.first.subgroup, 1);
    expect(out.last.subgroup, isNull);
  });

  test('output equals the prior in-line map(fromJson).toList() form', () {
    final raw = <Map<String, dynamic>>[
      sampleEntry(date: '2026-01-15', subjectNumber: 3, classroom: '203'),
      sampleEntry(
        date: '2026-01-15',
        subjectNumber: 3,
        subgroup: 2,
        classroom: '204',
      ),
      sampleEntry(
        date: '2026-01-16',
        subjectNumber: 1,
        isOverride: true,
      ),
    ];

    final viaParser = parseRaspisanieList(raw);
    final viaInline = raw.map(RaspisanieEntry.fromJson).toList();

    expect(viaParser.length, viaInline.length);
    for (var i = 0; i < viaParser.length; i++) {
      final a = viaParser[i];
      final b = viaInline[i];
      expect(a.date, b.date);
      expect(a.subjectNumber, b.subjectNumber);
      expect(a.subgroup, b.subgroup);
      expect(a.classroom, b.classroom);
      expect(a.group.id, b.group.id);
      expect(a.group.name, b.group.name);
      expect(a.teacher.id, b.teacher.id);
      expect(a.teacher.name, b.teacher.name);
      expect(a.subject.id, b.subject.id);
      expect(a.subject.name, b.subject.name);
      expect(a.isOverride, b.isOverride);
    }
  });

  test('handles empty input without an isolate spawn', () {
    // Empty case is short-circuited by the repository, but the parser
    // itself still needs to be empty-safe in case anyone calls it directly.
    final out = parseRaspisanieList(const <Map<String, dynamic>>[]);
    expect(out, isEmpty);
  });
}

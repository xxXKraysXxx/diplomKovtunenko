import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/api/raspisanie_repository.dart';
import 'package:ncti_schedule_client/models/raspisanie.dart';

/// 1.3.1 Item 1: the day-strip and week-list views aggregate
/// `monthRaspisanieByMonthProvider` results across multiple months whose
/// 6-row grid windows overlap. `dedupRaspisanieEntries` collapses literal
/// duplicates so each (date, slot, subgroup, …) tuple renders once.
void main() {
  RaspisanieEntry e({
    required String date,
    required int subjectNumber,
    int? subgroup,
    String classroom = '101',
    int groupId = 1,
    int teacherId = 11,
    int subjectId = 100,
    bool isOverride = false,
  }) {
    return RaspisanieEntry(
      date: DateTime.parse(date),
      subjectNumber: subjectNumber,
      subgroup: subgroup,
      classroom: classroom,
      group: NamedRef(id: groupId, name: 'G$groupId'),
      teacher: NamedRef(id: teacherId, name: 'T$teacherId'),
      subject: NamedRef(id: subjectId, name: 'Subj$subjectId'),
      isOverride: isOverride,
    );
  }

  group('dedupRaspisanieEntries', () {
    test('collapses identical rows from overlapping month windows', () {
      // April query and May query both return 2026-04-28's entries because
      // gridStartFor(May)=Apr 27 and gridEndFor(April)=May 10 overlap.
      final entries = [
        e(date: '2026-04-28', subjectNumber: 1, subgroup: null),
        e(date: '2026-04-28', subjectNumber: 2, subgroup: null),
        e(date: '2026-04-28', subjectNumber: 1, subgroup: null),
        e(date: '2026-04-28', subjectNumber: 2, subgroup: null),
      ];
      final out = dedupRaspisanieEntries(entries);
      expect(out, hasLength(2));
      expect(out.map((x) => x.subjectNumber).toSet(), {1, 2});
    });

    test('keeps split-lab entries with different teachers', () {
      // Same slot, same subject, different teachers = a real lab split. Must
      // survive dedup so both teachers' rows render.
      final entries = [
        e(date: '2026-04-28', subjectNumber: 3, subgroup: 1, teacherId: 11),
        e(date: '2026-04-28', subjectNumber: 3, subgroup: 2, teacherId: 22),
      ];
      final out = dedupRaspisanieEntries(entries);
      expect(out, hasLength(2));
    });

    test('keeps split-lab entries with different classrooms', () {
      final entries = [
        e(date: '2026-04-28', subjectNumber: 4, subgroup: 1, classroom: '101'),
        e(date: '2026-04-28', subjectNumber: 4, subgroup: 2, classroom: '102'),
      ];
      final out = dedupRaspisanieEntries(entries);
      expect(out, hasLength(2));
    });

    test('keeps subgroup variants (a vs b) — not folded on schedule screen',
        () {
      // Home widgets fold these; the schedule screen leaves both visible so
      // a student in subgroup 1 still sees their slot when it differs from
      // subgroup 2's.
      final entries = [
        e(date: '2026-04-28', subjectNumber: 1, subgroup: 1),
        e(date: '2026-04-28', subjectNumber: 1, subgroup: 2),
      ];
      final out = dedupRaspisanieEntries(entries);
      expect(out, hasLength(2));
    });

    test('treats null subgroup vs subgroup=1 as distinct', () {
      final entries = [
        e(date: '2026-04-28', subjectNumber: 1, subgroup: null),
        e(date: '2026-04-28', subjectNumber: 1, subgroup: 1),
      ];
      final out = dedupRaspisanieEntries(entries);
      expect(out, hasLength(2));
    });

    test('preserves order of first occurrence', () {
      final entries = [
        e(date: '2026-04-28', subjectNumber: 1),
        e(date: '2026-04-28', subjectNumber: 2),
        e(date: '2026-04-28', subjectNumber: 1),
      ];
      final out = dedupRaspisanieEntries(entries);
      expect(out.map((x) => x.subjectNumber).toList(), [1, 2]);
    });

    test('different dates with otherwise identical fields are kept', () {
      final entries = [
        e(date: '2026-04-28', subjectNumber: 1),
        e(date: '2026-04-29', subjectNumber: 1),
      ];
      final out = dedupRaspisanieEntries(entries);
      expect(out, hasLength(2));
    });

    test('empty input returns empty list', () {
      expect(dedupRaspisanieEntries(const []), isEmpty);
    });
  });
}

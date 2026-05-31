import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/models/raspisanie.dart';
import 'package:ncti_schedule_client/widgets_home/widget_updater.dart';

void main() {
  test('week widget shows next week on Sunday', () {
    final sunday = DateTime(2026, 5, 3);

    expect(weekSummaryAnchorMonday(sunday), DateTime(2026, 5, 4));
  });

  test('week widget stays on current week before Sunday', () {
    final monday = DateTime(2026, 4, 27);
    final saturday = DateTime(2026, 5, 2);

    expect(weekSummaryAnchorMonday(monday), DateTime(2026, 4, 27));
    expect(weekSummaryAnchorMonday(saturday), DateTime(2026, 4, 27));
  });

  test('week widget folds subgroup variants of the same slot and subject', () {
    final firstSubgroup = _entry(
      subgroup: 1,
      teacherId: 10,
      classroom: '201',
    );
    final secondSubgroup = _entry(
      subgroup: 2,
      teacherId: 11,
      classroom: '302',
    );

    expect(
      weekSummaryFoldKey(firstSubgroup),
      weekSummaryFoldKey(secondSubgroup),
    );
  });

  test('week widget keeps different slots or subjects separate', () {
    final base = _entry();
    final differentSlot = _entry(subjectNumber: 2);
    final differentSubject = _entry(subjectId: 200, subjectName: 'Физика');

    expect(weekSummaryFoldKey(base), isNot(weekSummaryFoldKey(differentSlot)));
    expect(
        weekSummaryFoldKey(base), isNot(weekSummaryFoldKey(differentSubject)));
  });
}

RaspisanieEntry _entry({
  int subjectNumber = 1,
  int? subgroup,
  int teacherId = 10,
  String classroom = '201',
  int subjectId = 100,
  String subjectName = 'Математика',
}) {
  return RaspisanieEntry(
    date: DateTime(2026, 5, 4),
    subjectNumber: subjectNumber,
    subgroup: subgroup,
    classroom: classroom,
    group: const NamedRef(id: 132, name: '132'),
    teacher: NamedRef(id: teacherId, name: 'Преподаватель $teacherId'),
    subject: NamedRef(id: subjectId, name: subjectName),
  );
}

import 'package:flutter/widgets.dart';

/// A single pair slot. `start`/`end` may be null for slots we know exist
/// by ordinal but have no conventional time (e.g. slot 10).
@immutable
class LessonSlot {
  final int ordinal;
  final String? start;
  final String? end;

  const LessonSlot({
    required this.ordinal,
    this.start,
    this.end,
  });

  bool get hasTime => start != null && end != null;

  String get label => hasTime ? '$start – $end' : '';
}

/// Times are easy to tweak here. Slots 6–9 extrapolate the existing cadence
/// for evening courses; slot 10 exists so rows with `subjectNumber: 10` have
/// a home, but carries no time label.
const List<LessonSlot> lessonSlots = <LessonSlot>[
  LessonSlot(ordinal: 1, start: '09:00', end: '10:30'),
  LessonSlot(ordinal: 2, start: '10:45', end: '12:20'),
  LessonSlot(ordinal: 3, start: '12:50', end: '14:25'),
  LessonSlot(ordinal: 4, start: '14:30', end: '15:55'),
  LessonSlot(ordinal: 5, start: '16:00', end: '17:30'),
  LessonSlot(ordinal: 6, start: '17:45', end: '19:15'),
  LessonSlot(ordinal: 7, start: '19:30', end: '21:00'),
  LessonSlot(ordinal: 8, start: '21:15', end: '22:45'),
  LessonSlot(ordinal: 9, start: '23:00', end: '00:30'),
  LessonSlot(ordinal: 10),
];

/// Returns the table slot for [ordinal] or a synthetic time-less slot when
/// an entry falls outside the table (e.g. `subjectNumber: 11`). Keeps the
/// UI tolerant to stray rows instead of silently dropping them.
LessonSlot slotForOrdinal(int ordinal) {
  for (final s in lessonSlots) {
    if (s.ordinal == ordinal) return s;
  }
  return LessonSlot(ordinal: ordinal);
}

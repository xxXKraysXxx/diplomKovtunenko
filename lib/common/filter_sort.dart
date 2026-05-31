import '../models/raspisanie.dart';

/// Client-side sort rules for filter dropdowns. Backend returns rows in the
/// order they live in the source tables (typically insertion order); none of
/// the callers depend on that order, so all sorting happens here to keep
/// filter UX stable across platforms.

final _groupSplit = RegExp(r'^([А-Яа-яA-Za-z]+)-?(\d+)$');

/// Groups sort by letter-prefix alphabetically, then by numeric suffix
/// ascending. `И-21` < `И-31` < `ИС-11` < `ИС-211` because "И" < "ИС"
/// lexicographically and numeric suffixes compare as integers (so `211`
/// sorts after `11` — not as a string where `"11" < "211"`). Names that
/// don't match the prefix-number pattern fall back to whole-string compare
/// and sort after the well-formed ones so weird legacy names don't wedge
/// themselves in the middle of a prefix run.
List<NamedRef> sortGroups(Iterable<NamedRef> xs) {
  final list = xs.toList();
  list.sort((a, b) {
    final ma = _groupSplit.firstMatch(a.name);
    final mb = _groupSplit.firstMatch(b.name);
    if (ma != null && mb != null) {
      final pa = ma.group(1)!;
      final pb = mb.group(1)!;
      final c = pa.compareTo(pb);
      if (c != 0) return c;
      final na = int.tryParse(ma.group(2)!) ?? 0;
      final nb = int.tryParse(mb.group(2)!) ?? 0;
      return na.compareTo(nb);
    }
    if (ma != null) return -1;
    if (mb != null) return 1;
    return a.name.compareTo(b.name);
  });
  return list;
}

/// Teachers: plain locale-naive alphabetical by full name. Cyrillic and
/// Latin both sort by code point, which matches the user's expectation on
/// a Russian-first list (uppercase А–Я < а–я < A–Z < a–z; all entries are
/// the same case in practice, so this is effectively alphabetical).
List<NamedRef> sortTeachers(Iterable<NamedRef> xs) {
  final list = xs.toList();
  list.sort((a, b) => a.name.compareTo(b.name));
  return list;
}

final _roomLectureSuffix = RegExp(r'\s*\(\s*л\s*\)\s*$');
final _leadingNumber = RegExp(r'^(\d+)');
const _gymName = 'Спортивный зал';

int _roomBucket(String name) {
  final n = name.trim();
  if (n == _gymName) return 3;
  if (_roomLectureSuffix.hasMatch(n)) return 0;
  if (_leadingNumber.hasMatch(n)) return 1;
  return 2;
}

int _leadingNumberOf(String s) {
  final m = _leadingNumber.firstMatch(s);
  if (m == null) return 0;
  return int.tryParse(m.group(1)!) ?? 0;
}

/// Rooms sort in four buckets:
///   0 — lecture halls (`NNN (л)`), sorted by the numeric prefix.
///   1 — plain numbered rooms (`101`, `205`, `205а`), sorted by the numeric
///       prefix then alphabetically on any trailing letter.
///   2 — other named rooms (non-numeric, non-gym), alphabetical.
///   3 — `Спортивный зал`, pinned to the very end.
List<String> sortRooms(Iterable<String> xs) {
  final list = xs.toList();
  list.sort((a, b) {
    final ba = _roomBucket(a);
    final bb = _roomBucket(b);
    if (ba != bb) return ba.compareTo(bb);
    if (ba == 0 || ba == 1) {
      final na = _leadingNumberOf(a);
      final nb = _leadingNumberOf(b);
      if (na != nb) return na.compareTo(nb);
      return a.compareTo(b);
    }
    return a.compareTo(b);
  });
  return list;
}

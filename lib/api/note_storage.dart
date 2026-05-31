import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/day_note.dart';
import '../state/auth.dart';
import '../state/note_queue.dart';
import 'raspisanie_repository.dart';

abstract class NoteStorage {
  Future<DayNote?> fetch(DateTime date);
  Future<DayNote?> fetchCached(DateTime date);
  Future<DayNote?> fetchFresh(DateTime date);
  Future<Set<DateTime>> fetchRange(DateTime from, DateTime to);
  Future<Set<DateTime>?> fetchRangeCached(DateTime from, DateTime to);
  Future<Set<DateTime>> fetchRangeFresh(DateTime from, DateTime to);
  Future<DayNote> set(DateTime date, String body);
  Future<bool> delete(DateTime date);
}

class ServerNoteStorage implements NoteStorage {
  ServerNoteStorage(
    this._repo,
    this._onFailure, {
    required this.enqueueSet,
    required this.enqueueDelete,
    required this.removeForDate,
    required this.flushQueue,
  });
  final RaspisanieRepository _repo;
  final Future<void> Function(OperationException) _onFailure;
  final Future<void> Function(DateTime date, String body) enqueueSet;
  final Future<void> Function(DateTime date) enqueueDelete;
  final Future<void> Function(DateTime date) removeForDate;
  final Future<void> Function() flushQueue;

  Future<T> _wrap<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on OperationException catch (e) {
      await _onFailure(e);
      rethrow;
    }
  }

  @override
  Future<DayNote?> fetch(DateTime date) =>
      _wrap(() => _repo.fetchDayNote(date));

  @override
  Future<DayNote?> fetchCached(DateTime date) {
    return _repo.fetchDayNoteCached(date);
  }

  @override
  Future<DayNote?> fetchFresh(DateTime date) {
    return _wrap(() => _repo.fetchDayNoteFresh(date));
  }

  @override
  Future<Set<DateTime>> fetchRange(DateTime from, DateTime to) async {
    final notes = await _wrap(() => _repo.fetchDayNotesRange(from, to));
    return _noteDates(notes);
  }

  @override
  Future<Set<DateTime>?> fetchRangeCached(DateTime from, DateTime to) async {
    final notes = await _repo.fetchDayNotesRangeCached(from, to);
    if (notes == null) return null;
    return _noteDates(notes);
  }

  @override
  Future<Set<DateTime>> fetchRangeFresh(DateTime from, DateTime to) async {
    final notes = await _wrap(() => _repo.fetchDayNotesRangeFresh(from, to));
    return _noteDates(notes);
  }

  Set<DateTime> _noteDates(List<DayNote> notes) {
    return notes
        .map((n) => DateTime(n.date.year, n.date.month, n.date.day))
        .toSet();
  }

  @override
  Future<DayNote> set(DateTime date, String body) async {
    final d = DateTime(date.year, date.month, date.day);
    try {
      final note = await _wrap(() => _repo.setDayNote(d, body));
      await removeForDate(d);
      // Piggyback: try to drain other queued ops now that we're online.
      unawaited(flushQueue());
      return note;
    } on OperationException catch (e) {
      if (e.graphqlErrors.isNotEmpty) {
        // Server-side rejection: drop any optimistic queue entry so the
        // outline doesn't stick.
        await removeForDate(d);
        rethrow;
      }
      // Network failure — enqueue and return an optimistic DayNote.
      await enqueueSet(d, body);
      return DayNote(
        id: 0,
        date: d,
        body: body,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
    }
  }

  @override
  Future<bool> delete(DateTime date) async {
    final d = DateTime(date.year, date.month, date.day);
    try {
      final ok = await _wrap(() => _repo.deleteDayNote(d));
      await removeForDate(d);
      unawaited(flushQueue());
      return ok;
    } on OperationException catch (e) {
      if (e.graphqlErrors.isNotEmpty) {
        await removeForDate(d);
        rethrow;
      }
      await enqueueDelete(d);
      return true;
    }
  }
}

class LocalNoteStorage implements NoteStorage {
  static const _key = 'guest_notes_v1';

  Future<Map<String, String>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(map));
  }

  String _isoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  DateTime _only(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Future<DayNote?> fetch(DateTime date) async {
    final all = await _readAll();
    final key = _isoDate(_only(date));
    final body = all[key];
    if (body == null || body.trim().isEmpty) return null;
    return DayNote(
      id: 0,
      date: _only(date),
      body: body,
      updatedAt: '',
    );
  }

  @override
  Future<DayNote?> fetchCached(DateTime date) => fetch(date);

  @override
  Future<DayNote?> fetchFresh(DateTime date) => fetch(date);

  @override
  Future<Set<DateTime>> fetchRange(DateTime from, DateTime to) async {
    final all = await _readAll();
    final lo = _only(from);
    final hi = _only(to);
    final result = <DateTime>{};
    for (final entry in all.entries) {
      if (entry.value.trim().isEmpty) continue;
      try {
        final d = DateTime.parse(entry.key);
        if (!d.isBefore(lo) && !d.isAfter(hi)) {
          result.add(_only(d));
        }
      } catch (_) {}
    }
    return result;
  }

  @override
  Future<Set<DateTime>?> fetchRangeCached(DateTime from, DateTime to) =>
      fetchRange(from, to);

  @override
  Future<Set<DateTime>> fetchRangeFresh(DateTime from, DateTime to) =>
      fetchRange(from, to);

  @override
  Future<DayNote> set(DateTime date, String body) async {
    final all = await _readAll();
    final key = _isoDate(_only(date));
    if (body.trim().isEmpty) {
      all.remove(key);
    } else {
      all[key] = body;
    }
    await _writeAll(all);
    return DayNote(
      id: 0,
      date: _only(date),
      body: body,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<bool> delete(DateTime date) async {
    final all = await _readAll();
    final key = _isoDate(_only(date));
    final existed = all.remove(key) != null;
    await _writeAll(all);
    return existed;
  }
}

final noteStorageProvider = Provider<NoteStorage>((ref) {
  final auth = ref.watch(authProvider).asData?.value;
  if (auth != null && auth.isAuthenticated) {
    return ServerNoteStorage(
      ref.watch(raspisanieRepositoryProvider),
      (e) => ref.read(authProvider.notifier).handleAuthOpFailure(e),
      enqueueSet: (d, b) =>
          ref.read(noteQueueProvider.notifier).enqueueSet(d, b),
      enqueueDelete: (d) =>
          ref.read(noteQueueProvider.notifier).enqueueDelete(d),
      removeForDate: (d) =>
          ref.read(noteQueueProvider.notifier).removeForDate(d),
      flushQueue: () => ref.read(noteQueueProvider.notifier).flush(),
    );
  }
  return LocalNoteStorage();
});

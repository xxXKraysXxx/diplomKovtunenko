import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/raspisanie_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart' show scaffoldMessengerKey;
import '../models/queued_note_op.dart';
import 'auth.dart';
import 'connectivity.dart';

/// Offline-write queue for day notes. Persists per-user in SharedPreferences
/// and flushes on connectivity restore / app resume / piggyback after a
/// successful online mutation.
class NoteQueue extends AsyncNotifier<List<QueuedNoteOp>> {
  static String _prefKey(int userId) => 'note_write_queue_${userId}_v1';

  int? _userId;
  bool _flushing = false;
  bool _lastOnline = true;

  @override
  Future<List<QueuedNoteOp>> build() async {
    final auth = ref.watch(authProvider).asData?.value;
    final userId = auth?.user?.id;
    _userId = userId;
    if (userId == null) return const <QueuedNoteOp>[];

    // Flush on online transitions (none -> online).
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (prev, next) {
      final nowOnline = next.asData?.value ?? false;
      final wasOnline = _lastOnline;
      _lastOnline = nowOnline;
      if (!wasOnline && nowOnline) {
        unawaited(flush());
      }
    });

    final loaded = await _load(userId);
    // Try an opportunistic flush shortly after load in case we came back up
    // while offline-but-reachable; cheap no-op if the queue is empty.
    if (loaded.isNotEmpty) {
      scheduleMicrotask(() => flush());
    }
    return loaded;
  }

  Future<List<QueuedNoteOp>> _load(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey(userId));
    if (raw == null || raw.isEmpty) return <QueuedNoteOp>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <QueuedNoteOp>[];
      for (final e in list) {
        final op = QueuedNoteOp.tryFromJson(e as Map<String, dynamic>);
        if (op != null) out.add(op);
      }
      return out;
    } catch (_) {
      return <QueuedNoteOp>[];
    }
  }

  Future<void> _persist(List<QueuedNoteOp> ops) async {
    final uid = _userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefKey(uid),
      jsonEncode(ops.map((o) => o.toJson()).toList()),
    );
  }

  List<QueuedNoteOp> _current() => state.asData?.value ?? const <QueuedNoteOp>[];

  bool get _hasAuth => _userId != null;

  Future<void> enqueueSet(DateTime date, String body) async {
    if (!_hasAuth) return;
    await _enqueue(QueuedNoteOp(
      id: _newId(),
      type: QueuedNoteOpType.set,
      date: dateOnly(date),
      body: body,
      queuedAt: DateTime.now().toUtc(),
    ));
  }

  Future<void> enqueueDelete(DateTime date) async {
    if (!_hasAuth) return;
    await _enqueue(QueuedNoteOp(
      id: _newId(),
      type: QueuedNoteOpType.delete,
      date: dateOnly(date),
      body: '',
      queuedAt: DateTime.now().toUtc(),
    ));
  }

  Future<void> _enqueue(QueuedNoteOp op) async {
    final next = [..._current().where((o) => !_sameDay(o.date, op.date)), op];
    state = AsyncValue.data(next);
    await _persist(next);
  }

  Future<void> removeForDate(DateTime date) async {
    if (!_hasAuth) return;
    final d = dateOnly(date);
    final next = _current().where((o) => !_sameDay(o.date, d)).toList();
    if (next.length == _current().length) return;
    state = AsyncValue.data(next);
    await _persist(next);
  }

  /// Attempts to send each queued op to the server, oldest-first. Succeeded
  /// ops are removed. A network failure stops the flush (items remain).
  /// A server-side rejection drops the offending op and surfaces a snackbar;
  /// callers should invalidate providers to pick up server truth.
  Future<void> flush() async {
    if (!_hasAuth) return;
    if (_flushing) return;
    final online = ref.read(isOnlineProvider).asData?.value ?? true;
    if (!online) return;
    _flushing = true;
    try {
      // Work on a snapshot; ops get removed from state individually.
      final snapshot = List<QueuedNoteOp>.from(_current());
      if (snapshot.isEmpty) return;
      snapshot.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
      final repo = ref.read(raspisanieRepositoryProvider);
      bool invalidated = false;

      for (final op in snapshot) {
        // Skip if the op was removed/replaced mid-flush.
        final stillQueued =
            _current().any((o) => o.id == op.id);
        if (!stillQueued) continue;
        try {
          if (op.type == QueuedNoteOpType.set) {
            await repo.setDayNote(op.date, op.body);
          } else {
            await repo.deleteDayNote(op.date);
          }
          await _removeById(op.id);
        } on OperationException catch (e) {
          if (e.graphqlErrors.isNotEmpty) {
            final msg = e.graphqlErrors.first.message;
            await _removeById(op.id);
            _showRejection(msg);
            invalidated = true;
          } else {
            // Network failure — stop flushing; retry next trigger.
            break;
          }
        } catch (_) {
          // Unknown; treat as network, stop flushing.
          break;
        }
      }
      if (invalidated) {
        ref.invalidate(dayNoteProvider);
        ref.invalidate(monthNotesProvider);
      }
    } finally {
      _flushing = false;
      try {
        ref.read(noteQueueTelemetryProvider.notifier).recordFlush();
      } catch (_) {}
    }
  }

  Future<void> _removeById(String id) async {
    final next = _current().where((o) => o.id != id).toList();
    state = AsyncValue.data(next);
    await _persist(next);
  }

  void _showRejection(String message) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final l10n = AppLocalizations.of(messenger.context);
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(l10n.noteQueueSaveError(message)),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _newId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

final noteQueueProvider =
    AsyncNotifierProvider<NoteQueue, List<QueuedNoteOp>>(NoteQueue.new);

/// Records the last time [NoteQueue.flush] ran to completion (success or
/// stop). Purely for the admin debug panel — no production UX depends on it.
class NoteQueueTelemetry extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void recordFlush() => state = DateTime.now();
}

final noteQueueTelemetryProvider =
    NotifierProvider<NoteQueueTelemetry, DateTime?>(NoteQueueTelemetry.new);

/// Returns the single currently-queued op for [date], or null if none.
QueuedNoteOp? queuedOpForDate(List<QueuedNoteOp> ops, DateTime date) {
  final d = dateOnly(date);
  for (final o in ops) {
    if (o.date.year == d.year &&
        o.date.month == d.month &&
        o.date.day == d.day) {
      return o;
    }
  }
  return null;
}

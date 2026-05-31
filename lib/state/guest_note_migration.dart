import 'dart:convert';

import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/queries.dart';

const _localNotesKey = 'guest_notes_v1';

/// Copies any locally stored guest notes to the server, skipping dates where
/// a teacher has already pinned a note or the user already has a server note
/// (server wins). Called once on the guest → authed transition. Network
/// failures leave entries in place so the next transition can retry; explicit
/// server rejections (bad date, etc.) drop the entry to avoid infinite retry.
Future<void> migrateGuestNotesToServer(GraphQLClient client) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_localNotesKey);
  if (raw == null || raw.isEmpty) return;

  Map<String, String> notes;
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    notes = decoded.map((k, v) => MapEntry(k, v.toString()));
  } catch (_) {
    await prefs.remove(_localNotesKey);
    return;
  }
  notes.removeWhere((k, v) => v.trim().isEmpty || _tryParseDate(k) == null);
  if (notes.isEmpty) {
    await prefs.remove(_localNotesKey);
    return;
  }

  final sortedKeys = notes.keys.toList()..sort();
  final from = sortedKeys.first;
  final to = sortedKeys.last;

  final existingServerDates = <String>{};
  final pinnedDates = <String>{};

  try {
    final r = await client.query(QueryOptions(
      document: gql(dayNotesRangeQuery),
      variables: {'from': from, 'to': to},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!r.hasException) {
      final list = (r.data?['dayNotes'] as List?) ?? const [];
      for (final raw in list.cast<Map<String, dynamic>>()) {
        final d = raw['date'] as String?;
        if (d != null) existingServerDates.add(d);
      }
    }
  } catch (_) {}

  try {
    final r = await client.query(QueryOptions(
      document: gql(pinnedNotesInRangeQuery),
      variables: {'from': from, 'to': to},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!r.hasException) {
      final list = (r.data?['pinnedNotesInRange'] as List?) ?? const [];
      for (final raw in list.cast<Map<String, dynamic>>()) {
        final d = raw['linkedDate'] as String?;
        if (d != null) pinnedDates.add(d);
      }
    }
  } catch (_) {}

  final remaining = Map<String, String>.from(notes);

  for (final entry in notes.entries) {
    final date = entry.key;
    if (existingServerDates.contains(date) || pinnedDates.contains(date)) {
      remaining.remove(date);
      continue;
    }
    try {
      final r = await client.mutate(MutationOptions(
        document: gql(setDayNoteMutation),
        variables: {'date': date, 'body': entry.value},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (!r.hasException) {
        remaining.remove(date);
      } else if (r.exception!.graphqlErrors.isNotEmpty) {
        remaining.remove(date);
      }
    } catch (_) {}
  }

  if (remaining.isEmpty) {
    await prefs.remove(_localNotesKey);
  } else {
    await prefs.setString(_localNotesKey, jsonEncode(remaining));
  }
}

DateTime? _tryParseDate(String iso) {
  if (iso.length != 10 || iso[4] != '-' || iso[7] != '-') return null;
  try {
    return DateTime.parse(iso);
  } catch (_) {
    return null;
  }
}

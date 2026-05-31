import 'dart:async';
import 'dart:io';

import 'package:graphql_flutter/graphql_flutter.dart';

import '../l10n/generated/app_localizations.dart';

/// Returns true for timeout, socket, and link-level network failures.
/// Returns false for server-side errors (bad credentials, validation, etc.).
bool isConnectionLike(Object e) {
  if (e is TimeoutException) return true;
  if (e is SocketException) return true;
  if (e is HttpException) return true;
  if (e is OperationException) return e.linkException != null;
  final s = e.toString().toLowerCase();
  return s.contains('timeout') ||
      s.contains('socketexception') ||
      s.contains('networkexception') ||
      s.contains('linkexception');
}

/// Translates auth-related exceptions to user-facing strings.
/// Connection failures → localized timeout message.
/// GraphQL server errors → the server's message (capitalized).
/// Anything else → capitalized toString.
String describeAuthError(AppLocalizations l10n, Object e) {
  if (isConnectionLike(e)) return l10n.authConnectionTimeout;
  if (e is OperationException && e.graphqlErrors.isNotEmpty) {
    return _capitalize(e.graphqlErrors.first.message);
  }
  return _capitalize(e.toString());
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

import '../l10n/generated/app_localizations.dart';

class AuditEvent {
  final int id;
  final int? userId;
  final String? userLogin;
  final String action;
  final String? details;
  final String? ip;
  final String createdAt;

  const AuditEvent({
    required this.id,
    required this.userId,
    required this.userLogin,
    required this.action,
    required this.details,
    required this.ip,
    required this.createdAt,
  });

  factory AuditEvent.fromJson(Map<String, dynamic> j) => AuditEvent(
        id: j['id'] as int,
        userId: j['userId'] as int?,
        userLogin: j['userLogin'] as String?,
        action: j['action'] as String,
        details: j['details'] as String?,
        ip: j['ip'] as String?,
        createdAt: j['createdAt'] as String,
      );
}

class ActionCount {
  final String action;
  final int count;
  const ActionCount({required this.action, required this.count});

  factory ActionCount.fromJson(Map<String, dynamic> j) => ActionCount(
        action: j['action'] as String,
        count: j['count'] as int,
      );
}

class ServerActivitySnapshot {
  final int registrations;
  final int failedLogins;
  final int passwordResets;
  final int notificationsSent;
  final List<ActionCount> countsByAction;
  final List<AuditEvent> recentEvents;

  const ServerActivitySnapshot({
    required this.registrations,
    required this.failedLogins,
    required this.passwordResets,
    required this.notificationsSent,
    required this.countsByAction,
    required this.recentEvents,
  });

  factory ServerActivitySnapshot.fromJson(Map<String, dynamic> j) {
    final counts = (j['countsByAction'] as List?) ?? const [];
    final events = (j['recentEvents'] as List?) ?? const [];
    return ServerActivitySnapshot(
      registrations: j['registrations'] as int? ?? 0,
      failedLogins: j['failedLogins'] as int? ?? 0,
      passwordResets: j['passwordResets'] as int? ?? 0,
      notificationsSent: j['notificationsSent'] as int? ?? 0,
      countsByAction: counts
          .cast<Map<String, dynamic>>()
          .map(ActionCount.fromJson)
          .toList(),
      recentEvents: events
          .cast<Map<String, dynamic>>()
          .map(AuditEvent.fromJson)
          .toList(),
    );
  }
}

String actionLabel(AppLocalizations l10n, String code) {
  switch (code) {
    case 'user.register':
      return l10n.activityLabelRegister;
    case 'user.login':
    case 'user.logged_in':
      return l10n.activityLabelLogin;
    case 'user.login_failed':
      return l10n.activityLabelLoginFailed;
    case 'user.logged_out':
      return l10n.activityLabelLoggedOut;
    case 'user.password_changed':
      return l10n.activityLabelPasswordChanged;
    case 'user.password_reset_by_admin':
      return l10n.activityLabelPasswordResetByAdmin;
    case 'user.created_by_admin':
      return l10n.activityLabelCreatedByAdmin;
    case 'user.deleted':
      return l10n.activityLabelUserDeleted;
    case 'user.canpush_toggled':
      return l10n.activityLabelCanPushToggled;
    case 'user.can_broadcast_globally_toggled':
      return l10n.activityLabelCanBroadcastGloballyToggled;
    case 'user.accent_color_set':
      return l10n.activityLabelAccentColorSet;
    case 'user.notif_prefs_set':
      return l10n.activityLabelNotifPrefsSet;
    case 'notification.sent':
      return l10n.activityLabelNotificationSent;
    case 'notification.deleted':
      return l10n.activityLabelNotificationDeleted;
    case 'device_token.registered':
      return l10n.activityLabelDeviceRegistered;
    case 'device_token.unregistered':
      return l10n.activityLabelDeviceUnregistered;
    case 'day_note.set':
      return l10n.activityLabelDayNoteSet;
    case 'day_note.deleted':
      return l10n.activityLabelDayNoteDeleted;
    case 'admin_setting.updated':
      return l10n.activityLabelAdminSettingUpdated;
    case 'news.scrape_triggered':
      return l10n.activityLabelNewsScrapeTriggered;
  }
  return code;
}

/// Filter category for the activity feed chip row.
enum ActivityFilter { all, users, notifications, notes, security }

String filterLabel(AppLocalizations l10n, ActivityFilter f) {
  switch (f) {
    case ActivityFilter.all:
      return l10n.activityFilterAll;
    case ActivityFilter.users:
      return l10n.activityFilterUsers;
    case ActivityFilter.notifications:
      return l10n.activityFilterNotifications;
    case ActivityFilter.notes:
      return l10n.activityFilterNotes;
    case ActivityFilter.security:
      return l10n.activityFilterSecurity;
  }
}

bool matchesFilter(String action, ActivityFilter f) {
  switch (f) {
    case ActivityFilter.all:
      return true;
    case ActivityFilter.users:
      return action.startsWith('user.register') ||
          action.startsWith('user.created') ||
          action.startsWith('user.deleted') ||
          action.startsWith('user.canpush') ||
          action == 'user.can_broadcast_globally_toggled' ||
          action == 'user.accent_color_set' ||
          action == 'user.notif_prefs_set';
    case ActivityFilter.notifications:
      return action.startsWith('notification.') ||
          action == 'news.scrape_triggered';
    case ActivityFilter.notes:
      return action.startsWith('day_note.');
    case ActivityFilter.security:
      return action == 'user.login' ||
          action == 'user.logged_in' ||
          action == 'user.logged_out' ||
          action == 'user.login_failed' ||
          action.startsWith('user.password') ||
          action.startsWith('device_token.');
  }
}

String formatBytes(AppLocalizations l10n, int n) {
  if (n < 1024) return l10n.bytesB('$n');
  if (n < 1024 * 1024) {
    final v = (n / 1024).round();
    return l10n.bytesKb('$v');
  }
  if (n < 1024 * 1024 * 1024) {
    final v = n / (1024 * 1024);
    return l10n.bytesMb(v.toStringAsFixed(1));
  }
  final v = n / (1024 * 1024 * 1024);
  return l10n.bytesGb(v.toStringAsFixed(1));
}

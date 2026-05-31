import '../l10n/generated/app_localizations.dart';

/// Application user roles. `system` is a hidden, server-only sender used for
/// college-sync notifications — the server blanks out id/login/accentColor
/// for these so we never have a real "logged-in SYSTEM user", but the role
/// still appears in the [Notification.sender] payload, so the enum must
/// decode it without throwing.
enum UserRole { admin, teacher, student, system }

UserRole _roleFromString(String s) {
  switch (s.toUpperCase()) {
    case 'ADMIN':
      return UserRole.admin;
    case 'TEACHER':
      return UserRole.teacher;
    case 'STUDENT':
      return UserRole.student;
    case 'SYSTEM':
      return UserRole.system;
  }
  throw ArgumentError('unknown role: $s');
}

String roleToString(UserRole r) {
  switch (r) {
    case UserRole.admin:
      return 'ADMIN';
    case UserRole.teacher:
      return 'TEACHER';
    case UserRole.student:
      return 'STUDENT';
    case UserRole.system:
      return 'SYSTEM';
  }
}

String roleLabel(AppLocalizations l10n, UserRole r) {
  switch (r) {
    case UserRole.admin:
      return l10n.roleAdmin;
    case UserRole.teacher:
      return l10n.roleTeacher;
    case UserRole.student:
      return l10n.roleStudent;
    case UserRole.system:
      return l10n.roleSystem;
  }
}

class UserStorage {
  final int noteBytes;
  final int notificationBytes;
  final int deviceTokenCount;
  final int totalBytes;

  const UserStorage({
    required this.noteBytes,
    required this.notificationBytes,
    required this.deviceTokenCount,
    required this.totalBytes,
  });

  factory UserStorage.fromJson(Map<String, dynamic> j) => UserStorage(
        noteBytes: j['noteBytes'] as int? ?? 0,
        notificationBytes: j['notificationBytes'] as int? ?? 0,
        deviceTokenCount: j['deviceTokenCount'] as int? ?? 0,
        totalBytes: j['totalBytes'] as int? ?? 0,
      );
}

class AppUser {
  final int id;
  final String login;
  final UserRole role;
  final int? groupId;
  final int? teacherId;
  final bool canPush;
  final bool canBroadcastGlobally;
  final String? accentColor;
  final String lastActivityAt;
  final String createdAt;
  final UserStorage? storage;

  const AppUser({
    required this.id,
    required this.login,
    required this.role,
    required this.groupId,
    required this.teacherId,
    required this.canPush,
    this.canBroadcastGlobally = false,
    required this.accentColor,
    required this.lastActivityAt,
    required this.createdAt,
    this.storage,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        login: j['login'] as String,
        role: _roleFromString(j['role'] as String),
        groupId: j['groupId'] as int?,
        teacherId: j['teacherId'] as int?,
        canPush: j['canPush'] as bool? ?? false,
        canBroadcastGlobally: j['canBroadcastGlobally'] as bool? ?? false,
        accentColor: j['accentColor'] as String?,
        lastActivityAt: j['lastActivityAt'] as String? ?? '',
        createdAt: j['createdAt'] as String? ?? '',
        storage: j['storage'] == null
            ? null
            : UserStorage.fromJson(j['storage'] as Map<String, dynamic>),
      );
}

class ScheduleDefaultFilter {
  final List<int> groupIds;
  final List<int> teacherIds;

  const ScheduleDefaultFilter({
    this.groupIds = const [],
    this.teacherIds = const [],
  });

  factory ScheduleDefaultFilter.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ScheduleDefaultFilter();
    final g = (j['groupIds'] as List?)?.cast<int>() ?? const <int>[];
    final t = (j['teacherIds'] as List?)?.cast<int>() ?? const <int>[];
    return ScheduleDefaultFilter(groupIds: g, teacherIds: t);
  }

  bool get isEmpty => groupIds.isEmpty && teacherIds.isEmpty;
}

class LoginPayload {
  final String token;
  final AppUser user;
  final ScheduleDefaultFilter defaultFilter;

  const LoginPayload({
    required this.token,
    required this.user,
    required this.defaultFilter,
  });

  factory LoginPayload.fromJson(Map<String, dynamic> j) => LoginPayload(
        token: j['token'] as String,
        user: AppUser.fromJson(j['user'] as Map<String, dynamic>),
        defaultFilter: ScheduleDefaultFilter.fromJson(
          j['defaultFilter'] as Map<String, dynamic>?,
        ),
      );
}

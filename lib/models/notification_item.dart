import 'app_user.dart';

enum NotificationScope { global, group }

NotificationScope _scopeFromString(String s) {
  switch (s.toUpperCase()) {
    case 'GLOBAL':
      return NotificationScope.global;
    case 'GROUP':
      return NotificationScope.group;
  }
  throw ArgumentError('unknown scope: $s');
}

String scopeToString(NotificationScope s) =>
    s == NotificationScope.global ? 'GLOBAL' : 'GROUP';

class NotificationSender {
  final int id;
  final String login;
  final UserRole role;
  final String? accentColor;
  const NotificationSender({
    required this.id,
    required this.login,
    required this.role,
    required this.accentColor,
  });

  factory NotificationSender.fromJson(Map<String, dynamic> j) =>
      NotificationSender(
        id: j['id'] as int,
        login: j['login'] as String,
        role: _roleFromJson(j['role'] as String),
        accentColor: j['accentColor'] as String?,
      );
}

UserRole _roleFromJson(String s) {
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
  return UserRole.student;
}

class NotificationItem {
  final int id;
  final int senderUserId;
  final NotificationSender sender;
  final NotificationScope scope;
  final String body;
  final DateTime? linkedDate;
  final List<int> targetGroupIds;
  final DateTime createdAt;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.senderUserId,
    required this.sender,
    required this.scope,
    required this.body,
    required this.linkedDate,
    required this.targetGroupIds,
    required this.createdAt,
    required this.isRead,
  });

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        senderUserId: senderUserId,
        sender: sender,
        scope: scope,
        body: body,
        linkedDate: linkedDate,
        targetGroupIds: targetGroupIds,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  factory NotificationItem.fromJson(Map<String, dynamic> j) {
    final ld = j['linkedDate'] as String?;
    return NotificationItem(
      id: j['id'] as int,
      senderUserId: j['senderUserId'] as int,
      sender: NotificationSender.fromJson(
        j['sender'] as Map<String, dynamic>,
      ),
      scope: _scopeFromString(j['scope'] as String),
      body: j['body'] as String,
      linkedDate: ld == null || ld.isEmpty ? null : _parseDate(ld),
      targetGroupIds:
          ((j['targetGroupIds'] as List?) ?? const []).cast<int>(),
      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      isRead: j['isRead'] as bool? ?? false,
    );
  }
}

DateTime _parseDate(String iso) {
  // Accept plain YYYY-MM-DD or ISO timestamp.
  if (iso.length == 10) {
    final p = iso.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
  final d = DateTime.parse(iso).toLocal();
  return DateTime(d.year, d.month, d.day);
}

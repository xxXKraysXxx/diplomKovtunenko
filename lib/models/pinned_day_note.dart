import 'notification_item.dart';

class PinnedDayNote {
  final int notificationId;
  final NotificationSender sender;
  final String body;
  final DateTime linkedDate;
  final DateTime createdAt;

  const PinnedDayNote({
    required this.notificationId,
    required this.sender,
    required this.body,
    required this.linkedDate,
    required this.createdAt,
  });

  factory PinnedDayNote.fromJson(Map<String, dynamic> j) {
    return PinnedDayNote(
      notificationId: j['notificationId'] as int,
      sender: NotificationSender.fromJson(
        j['sender'] as Map<String, dynamic>,
      ),
      body: j['body'] as String,
      linkedDate: _parseDate(j['linkedDate'] as String),
      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
    );
  }
}

DateTime _parseDate(String iso) {
  if (iso.length == 10) {
    final p = iso.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
  final d = DateTime.parse(iso).toLocal();
  return DateTime(d.year, d.month, d.day);
}

enum QueuedNoteOpType { set, delete }

String _typeToString(QueuedNoteOpType t) =>
    t == QueuedNoteOpType.set ? 'set' : 'delete';

QueuedNoteOpType _typeFromString(String s) =>
    s == 'delete' ? QueuedNoteOpType.delete : QueuedNoteOpType.set;

class QueuedNoteOp {
  final String id;
  final QueuedNoteOpType type;
  final DateTime date;
  final String body;
  final DateTime queuedAt;

  const QueuedNoteOp({
    required this.id,
    required this.type,
    required this.date,
    required this.body,
    required this.queuedAt,
  });

  QueuedNoteOp copyWith({String? id, DateTime? queuedAt}) => QueuedNoteOp(
        id: id ?? this.id,
        type: type,
        date: date,
        body: body,
        queuedAt: queuedAt ?? this.queuedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': _typeToString(type),
        'date': _iso(date),
        'body': body,
        'queued_at': queuedAt.toUtc().toIso8601String(),
      };

  static QueuedNoteOp? tryFromJson(Map<String, dynamic> j) {
    try {
      return QueuedNoteOp(
        id: j['id'] as String,
        type: _typeFromString(j['type'] as String),
        date: DateTime.parse(j['date'] as String),
        body: (j['body'] as String?) ?? '',
        queuedAt: DateTime.parse(j['queued_at'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  static String _iso(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

import 'package:t/t.dart' as t;

/// Represents a message in Telegram.
class TeliMessage {
  final int id;
  final DateTime date;
  final String? text;
  final int? senderId;
  final bool isService;

  const TeliMessage({
    required this.id,
    required this.date,
    this.text,
    this.senderId,
    this.isService = false,
  });

  factory TeliMessage.fromRaw(t.MessageBase raw) {
    return switch (raw) {
      t.Message m => TeliMessage(
          id: m.id,
          date: m.date,
          text: m.message,
          senderId: m.fromId is t.PeerUser ? (m.fromId as t.PeerUser).userId : null,
          isService: false,
        ),
      t.MessageService ms => TeliMessage(
          id: ms.id,
          date: ms.date,
          isService: true,
        ),
      _ => throw ArgumentError('Unsupported message type: ${raw.runtimeType}'),
    };
  }

  @override
  String toString() => 'TeliMessage(id: $id, date: $date, text: $text)';
}

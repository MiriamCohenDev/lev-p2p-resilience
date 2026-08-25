import '../../../core/id.dart';

/// One message in a conversation (technical-spec §6.1).
///
/// [fromUser] is the only distinction between a user turn and an assistant
/// turn — there is no third participant and no server.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.fromUser,
    required this.createdAt,
  });

  factory Message.fromUserInput({
    required String conversationId,
    required String text,
    String? id,
    DateTime? createdAt,
  }) =>
      Message(
        id: id ?? newId(),
        conversationId: conversationId,
        text: text,
        fromUser: true,
        createdAt: createdAt ?? DateTime.now(),
      );

  factory Message.fromAssistant({
    required String conversationId,
    required String text,
    String? id,
    DateTime? createdAt,
  }) =>
      Message(
        id: id ?? newId(),
        conversationId: conversationId,
        text: text,
        fromUser: false,
        createdAt: createdAt ?? DateTime.now(),
      );

  final String id;
  final String conversationId;
  final String text;
  final bool fromUser;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is Message &&
      other.id == id &&
      other.conversationId == conversationId &&
      other.text == text &&
      other.fromUser == fromUser &&
      other.createdAt.isAtSameMomentAs(createdAt);

  @override
  int get hashCode =>
      Object.hash(id, conversationId, text, fromUser, createdAt);

  @override
  String toString() =>
      'Message($id, ${fromUser ? 'user' : 'assistant'}, "$text")';
}

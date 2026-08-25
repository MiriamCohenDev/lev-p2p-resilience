import '../../../core/id.dart';
import 'message_role.dart';

/// One message in a conversation (technical-spec §6.1).
///
/// [role] is three-valued rather than a "from user" boolean — see
/// [MessageRole] and technical-decisions #15.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.role,
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
        role: MessageRole.user,
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
        role: MessageRole.assistant,
        createdAt: createdAt ?? DateTime.now(),
      );

  factory Message.fromSystem({
    required String conversationId,
    required String text,
    String? id,
    DateTime? createdAt,
  }) =>
      Message(
        id: id ?? newId(),
        conversationId: conversationId,
        text: text,
        role: MessageRole.system,
        createdAt: createdAt ?? DateTime.now(),
      );

  final String id;
  final String conversationId;
  final String text;
  final MessageRole role;
  final DateTime createdAt;

  /// Convenience for the presentation layer, which only ever asks which side of
  /// the conversation a bubble belongs on.
  bool get isFromUser => role == MessageRole.user;

  Message copyWith({String? text}) => Message(
        id: id,
        conversationId: conversationId,
        text: text ?? this.text,
        role: role,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Message &&
      other.id == id &&
      other.conversationId == conversationId &&
      other.text == text &&
      other.role == role &&
      other.createdAt.isAtSameMomentAs(createdAt);

  @override
  int get hashCode => Object.hash(id, conversationId, text, role, createdAt);

  @override
  String toString() => 'Message($id, ${role.wireName}, "$text")';
}

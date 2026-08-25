import '../../../core/id.dart';

/// A conversation with the assistant (technical-spec §6.1).
///
/// Pure Dart: the domain layer knows nothing about drift or SQL (§3.2).
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Mints a new conversation. [id] and [createdAt] are injectable so a test can
  /// pin them — the same reason `SecureRandomSource` is abstracted in
  /// `core/crypto/key_material.dart`.
  factory Conversation.create({
    required String title,
    String? id,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return Conversation(
      id: id ?? newId(),
      title: title,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String title;
  final DateTime createdAt;

  /// Last time a message was appended. What the conversation list sorts by.
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is Conversation &&
      other.id == id &&
      other.title == title &&
      other.createdAt.isAtSameMomentAs(createdAt) &&
      other.updatedAt.isAtSameMomentAs(updatedAt);

  @override
  int get hashCode => Object.hash(id, title, createdAt, updatedAt);

  @override
  String toString() => 'Conversation($id, "$title")';
}

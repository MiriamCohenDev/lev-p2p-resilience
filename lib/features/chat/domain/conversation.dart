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
    this.summary,
    this.summaryUpToMessageId,
    this.systemPromptVersion,
    this.modelId,
    this.isDeleted = false,
  });

  /// Mints a new conversation. [id] and [createdAt] are injectable so a test can
  /// pin them — the same reason `SecureRandomSource` is abstracted in
  /// `core/crypto/key_material.dart`.
  ///
  /// [systemPromptVersion] and [modelId] are stamped at creation, not at first
  /// message: §5.2.1 wants a change in behaviour traceable to a prompt version,
  /// which only works if every conversation records the version it was held
  /// under. They are nullable because Phase 2.0 predates the prompt layer.
  factory Conversation.create({
    required String title,
    String? id,
    DateTime? createdAt,
    String? systemPromptVersion,
    String? modelId,
  }) {
    final now = createdAt ?? DateTime.now();
    return Conversation(
      id: id ?? newId(),
      title: title,
      createdAt: now,
      updatedAt: now,
      systemPromptVersion: systemPromptVersion,
      modelId: modelId,
    );
  }

  final String id;
  final String title;
  final DateTime createdAt;

  /// Last time a message was appended. What the conversation list sorts by.
  final DateTime updatedAt;

  /// The rolling summary of turns that no longer fit the context budget
  /// (§5.2.3). Persisted rather than regenerated on every reopen — regenerating
  /// it is exactly the cost it exists to avoid.
  final String? summary;

  /// The last message [summary] accounts for. Everything after it is still
  /// carried verbatim.
  final String? summaryUpToMessageId;

  /// The version of `assets/prompts/system_prompt.md` this conversation was
  /// held under (§5.2.1).
  final String? systemPromptVersion;

  /// The `ModelDescriptor.id` active when this conversation was created (§5.3).
  final String? modelId;

  /// Tombstone (§6.1). A deleted conversation keeps its row and loses its
  /// messages — see `ChatDao.deleteConversation` and technical-decisions #15.
  final bool isDeleted;

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    String? summary,
    String? summaryUpToMessageId,
    bool? isDeleted,
  }) =>
      Conversation(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        summary: summary ?? this.summary,
        summaryUpToMessageId: summaryUpToMessageId ?? this.summaryUpToMessageId,
        systemPromptVersion: systemPromptVersion,
        modelId: modelId,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  @override
  bool operator ==(Object other) =>
      other is Conversation &&
      other.id == id &&
      other.title == title &&
      other.createdAt.isAtSameMomentAs(createdAt) &&
      other.updatedAt.isAtSameMomentAs(updatedAt) &&
      other.summary == summary &&
      other.summaryUpToMessageId == summaryUpToMessageId &&
      other.systemPromptVersion == systemPromptVersion &&
      other.modelId == modelId &&
      other.isDeleted == isDeleted;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        createdAt,
        updatedAt,
        summary,
        summaryUpToMessageId,
        systemPromptVersion,
        modelId,
        isDeleted,
      );

  @override
  String toString() => 'Conversation($id, "$title")';
}

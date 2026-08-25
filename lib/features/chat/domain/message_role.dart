/// Who produced a message (technical-spec §6.1).
///
/// Three-valued, not a boolean. §6.1 is explicit about this: the chat template
/// (§5.2.2) maps roles to model-specific markers, and a boolean cannot represent
/// [system] at all. See technical-decisions #15.
enum MessageRole {
  user,
  assistant,

  /// Reserved for prompt-layer content that is stored as part of a conversation
  /// rather than assembled at render time. Nothing in Phase 2 writes it; the
  /// role exists so that doing so later is not a schema change.
  system;

  /// The stored form. Explicit rather than [name] so that renaming a Dart
  /// identifier can never silently rewrite what is already on disk.
  String get wireName => switch (this) {
        MessageRole.user => 'user',
        MessageRole.assistant => 'assistant',
        MessageRole.system => 'system',
      };

  /// Parses the stored form.
  ///
  /// Throws [FormatException] on anything else: an unrecognised role in the
  /// database means the row was written by a version that knew something this
  /// one does not, and guessing would put words in the wrong speaker's mouth.
  static MessageRole fromWireName(String value) => switch (value) {
        'user' => MessageRole.user,
        'assistant' => MessageRole.assistant,
        'system' => MessageRole.system,
        _ => throw FormatException('unknown message role', value),
      };
}

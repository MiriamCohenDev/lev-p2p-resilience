/// The assistant's instructions and the version they came from
/// (technical-spec §5.2.1).
///
/// The version is recorded on every conversation, so a later change in the
/// assistant's behaviour is traceable to the prompt that produced it. That only
/// works if the version travels with the text rather than being remembered
/// separately, which is why they are one object.
class SystemPrompt {
  const SystemPrompt({required this.version, required this.text});

  /// Parses `assets/prompts/system_prompt.md`.
  ///
  /// The file opens with a small YAML-ish front-matter block holding the
  /// version. Parsed by hand rather than with a YAML package: it is three lines
  /// with one key, and a dependency for that would be worse than the ten lines
  /// below.
  factory SystemPrompt.parse(String source) {
    final normalised = source.replaceAll('\r\n', '\n');
    final match = RegExp(
      r'^---\n(.*?)\n---\n(.*)$',
      dotAll: true,
    ).firstMatch(normalised);

    if (match == null) {
      throw const FormatException(
        'system_prompt.md must open with a "---" front-matter block '
        'declaring its version',
      );
    }

    final version = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(match[1]!)
        ?.group(1);
    if (version == null) {
      throw const FormatException(
        'system_prompt.md front matter declares no version. §5.2.1 records it '
        'on every conversation, so it cannot be optional.',
      );
    }

    final text = match[2]!.trim();
    if (text.isEmpty) {
      throw const FormatException('system_prompt.md has no body');
    }

    return SystemPrompt(version: version, text: text);
  }

  final String version;
  final String text;
}

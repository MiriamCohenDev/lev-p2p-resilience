/// Failures the inference layer can report.
///
/// Sealed and typed for the same reason `crypto_errors.dart` and
/// `database_errors.dart` are: the caller's correct response differs per case,
/// and a bare `Exception` erases the difference. Here the split that matters is
/// "try again" versus "this conversation cannot continue".
sealed class LlmException implements Exception {
  const LlmException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// No model is loaded, or the one requested could not be.
///
/// In Phase 2 this is a programming error — the fake loads unconditionally. In
/// Phase 3 it covers a missing GGUF, a failed integrity check (§7.5), and a
/// device below the descriptor's `minRamMb`.
class ModelUnavailable extends LlmException {
  const ModelUnavailable(super.message, {super.cause});
}

/// The registry holds no model matching what was asked for.
class NoSuitableModel extends LlmException {
  const NoSuitableModel(super.message, {super.cause});
}

/// The weights on disk are not the weights the manifest pins (§7.5).
///
/// Distinct from [ModelUnavailable] because the two mean opposite things about
/// the file: "there is nothing here" is an installation that has not finished,
/// while "this is not what it claims to be" is a corrupt download or a tampered
/// file. Only the second is a reason to refuse a file that is sitting right
/// there, and only the second should ever be surfaced as a warning rather than
/// as a setup step.
class ModelIntegrityFailed extends LlmException {
  const ModelIntegrityFailed(super.message, {super.cause});
}

/// The manifest under `assets/models/` could not be read or parsed.
class ModelManifestInvalid extends LlmException {
  const ModelManifestInvalid(super.message, {super.cause});
}

/// Generation failed part-way through.
///
/// Whatever tokens already reached the UI are real and stay on screen; this
/// says the rest is not coming.
class GenerationFailed extends LlmException {
  const GenerationFailed(super.message, {super.cause});
}

/// A session was used after it was disposed.
class SessionClosed extends LlmException {
  const SessionClosed(super.message, {super.cause});
}

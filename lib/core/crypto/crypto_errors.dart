/// Typed failures raised by the key-management module.
///
/// The hierarchy exists to keep one distinction visible to every caller:
/// key material that is **cleanly absent** (a first run) is not the same as key
/// material that **could not be read**. Generating a fresh DEK after a read
/// failure would silently orphan an existing encrypted database — with no
/// server and no backup, that is unrecoverable data loss. So a failure is
/// always an exception here, never a `null` that reads like "not there yet".
sealed class KeyManagementException implements Exception {
  const KeyManagementException(this.message, {this.cause});

  final String message;

  /// The underlying platform error, when there was one.
  final Object? cause;

  @override
  String toString() => cause == null
      ? '$runtimeType: $message'
      : '$runtimeType: $message (cause: $cause)';
}

/// The operating system's secure store could not serve the request at all.
///
/// Typical causes: `libsecret` missing or the Secret Service daemon not running
/// on Linux, a locked keyring, or an Android Keystore that threw. Recoverable in
/// principle — the same call may succeed on the next launch — so callers should
/// surface it as a diagnosable condition rather than treat the device as new.
class KeyStoreUnavailable extends KeyManagementException {
  const KeyStoreUnavailable(super.message, {super.cause});
}

/// A value was returned by the secure store but is not what we wrote:
/// malformed base64, a truncated record, an unknown envelope version.
class KeyStoreCorrupted extends KeyManagementException {
  const KeyStoreCorrupted(super.message, {super.cause});
}

/// AES-GCM authentication failed while unwrapping the DEK.
///
/// Means the KEK is not the one the DEK was wrapped with, or the stored
/// envelope was altered. Never means "no key yet".
class DekUnwrapFailed extends KeyManagementException {
  const DekUnwrapFailed(super.message, {super.cause});
}

/// Which half of the key material was absent in an inconsistent state.
enum MissingKeyMaterial {
  /// The KEK is gone but a wrapped DEK survives — the severe direction.
  kek,

  /// The KEK survives but the wrapped DEK is gone.
  wrappedDek,
}

/// Some key material is present and some is absent.
///
/// This is never treated as a first run. The [MissingKeyMaterial.kek] direction
/// in particular means an encrypted database may exist on disk that can no
/// longer be opened by anyone, ever — provisioning a new DEK on top of it would
/// destroy it silently instead of failing loudly.
class KeyMaterialMissing extends KeyManagementException {
  const KeyMaterialMissing(this.missing, super.message, {super.cause});

  final MissingKeyMaterial missing;
}

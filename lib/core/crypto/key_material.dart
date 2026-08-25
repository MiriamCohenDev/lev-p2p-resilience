import 'dart:math';
import 'dart:typed_data';

/// Length of both the DEK and the KEK, in bytes. AES-256 either way.
const int keyLengthBytes = 32;

/// Source of cryptographically secure random bytes.
///
/// Abstracted so tests can pin the bytes a run produces; production always uses
/// [DartSecureRandom].
abstract class SecureRandomSource {
  Uint8List nextBytes(int length);
}

/// [SecureRandomSource] backed by `Random.secure()`, which draws from the
/// platform CSPRNG (`/dev/urandom`, `BCryptGenRandom`, …) on every target.
class DartSecureRandom implements SecureRandomSource {
  DartSecureRandom([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  @override
  Uint8List nextBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}

/// Overwrites [bytes] in place.
///
/// Best-effort: Dart makes no promise that the VM has not already copied the
/// buffer elsewhere, and there is no `mlock` equivalent. Still worth doing for
/// key material whose lifetime we control.
void wipe(Uint8List bytes) => bytes.fillRange(0, bytes.length, 0);

/// Formats a raw DEK as the literal SQLCipher expects for a raw key:
/// `x'<64 hex chars>'`.
///
/// The `x'…'` form tells SQLCipher the value *is* the key, skipping its own
/// PBKDF2 derivation — correct here, because the DEK is already 32 random bytes.
/// Pure string formatting; deliberately carries no dependency on Drift, so the
/// storage layer can consume it without this module knowing anything about it.
String toSqlCipherKey(Uint8List dek) {
  if (dek.length != keyLengthBytes) {
    throw ArgumentError.value(
      dek.length,
      'dek.length',
      'expected $keyLengthBytes bytes',
    );
  }
  final hex = StringBuffer();
  for (final byte in dek) {
    hex.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return "x'$hex'";
}

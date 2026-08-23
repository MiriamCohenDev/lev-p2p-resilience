import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';

import 'crypto_errors.dart';

/// Wraps and unwraps the DEK with the KEK, using AES-256-GCM.
///
/// GCM is authenticated: unwrapping with the wrong KEK, or with an envelope
/// somebody edited, fails loudly instead of yielding plausible garbage that
/// would later surface as an unreadable database.
///
/// On-the-wire layout, base64-encoded:
///
/// ```text
/// version(1) ‖ nonce(12) ‖ ciphertext(32) ‖ mac(16)
/// ```
///
/// The leading version byte is what lets the algorithm change later without
/// stranding installations already on disk.
class KeyEnvelope {
  const KeyEnvelope._();

  static const int _version = 1;
  static const int _nonceLength = 12;
  static const int _macLength = 16;

  static final AesGcm _cipher = AesGcm.with256bits(nonceLength: _nonceLength);

  /// Encrypts [dek] under [kek]. A fresh random nonce is drawn per call, so
  /// wrapping the same DEK twice never produces the same envelope.
  static Future<String> wrap(Uint8List dek, Uint8List kek) async {
    final box = await _cipher.encrypt(dek, secretKey: SecretKey(kek));
    final body = box.concatenation();
    final envelope = Uint8List(1 + body.length);
    envelope[0] = _version;
    envelope.setRange(1, envelope.length, body);
    return base64Encode(envelope);
  }

  /// Recovers the DEK from [envelope].
  ///
  /// Throws [KeyStoreCorrupted] if the envelope is not one of ours, and
  /// [DekUnwrapFailed] if it is but the KEK does not authenticate it.
  static Future<Uint8List> unwrap(String envelope, Uint8List kek) async {
    final Uint8List raw;
    try {
      raw = base64Decode(envelope);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        KeyStoreCorrupted('wrapped DEK is not valid base64', cause: error),
        stackTrace,
      );
    }

    if (raw.isEmpty) {
      throw const KeyStoreCorrupted('wrapped DEK is empty');
    }
    if (raw[0] != _version) {
      throw KeyStoreCorrupted(
        'unknown key envelope version ${raw[0]}, expected $_version',
      );
    }
    if (raw.length <= 1 + _nonceLength + _macLength) {
      throw KeyStoreCorrupted(
        'wrapped DEK is ${raw.length} bytes, too short to hold a nonce, '
        'ciphertext and MAC',
      );
    }

    final box = SecretBox.fromConcatenation(
      Uint8List.sublistView(raw, 1),
      nonceLength: _nonceLength,
      macLength: _macLength,
    );
    try {
      final dek = await _cipher.decrypt(box, secretKey: SecretKey(kek));
      return Uint8List.fromList(dek);
    } on SecretBoxAuthenticationError catch (error, stackTrace) {
      Error.throwWithStackTrace(
        DekUnwrapFailed(
          'the DEK could not be authenticated with this KEK — either the KEK '
          'is not the one it was wrapped with, or the stored envelope was '
          'altered',
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}

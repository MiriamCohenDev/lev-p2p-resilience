import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/crypto/crypto_errors.dart';
import 'package:lev/core/crypto/key_envelope.dart';
import 'package:lev/core/crypto/key_material.dart';

void main() {
  Uint8List bytesFilledWith(int value) =>
      Uint8List(keyLengthBytes)..fillRange(0, keyLengthBytes, value);

  final dek = bytesFilledWith(0xA1);
  final kek = bytesFilledWith(0xB2);
  final otherKek = bytesFilledWith(0xC3);

  test('a wrapped DEK unwraps back to the same bytes', () async {
    final envelope = await KeyEnvelope.wrap(dek, kek);

    expect(await KeyEnvelope.unwrap(envelope, kek), equals(dek));
  });

  test('the envelope does not contain the DEK in the clear', () async {
    final envelope = await KeyEnvelope.wrap(dek, kek);

    expect(base64Decode(envelope), isNot(containsAllInOrder(dek)));
  });

  test('wrapping the same DEK twice draws a fresh nonce', () async {
    final first = await KeyEnvelope.wrap(dek, kek);
    final second = await KeyEnvelope.wrap(dek, kek);

    expect(first, isNot(equals(second)));
    expect(await KeyEnvelope.unwrap(first, kek), equals(dek));
    expect(await KeyEnvelope.unwrap(second, kek), equals(dek));
  });

  test('unwrapping with the wrong KEK fails authentication', () async {
    final envelope = await KeyEnvelope.wrap(dek, kek);

    expect(
      () => KeyEnvelope.unwrap(envelope, otherKek),
      throwsA(isA<DekUnwrapFailed>()),
    );
  });

  test('a single altered byte fails authentication', () async {
    final raw = base64Decode(await KeyEnvelope.wrap(dek, kek));
    // Past the version byte and the nonce, so this hits the ciphertext.
    raw[20] ^= 0xFF;

    expect(
      () => KeyEnvelope.unwrap(base64Encode(raw), kek),
      throwsA(isA<DekUnwrapFailed>()),
    );
  });

  test('an unknown envelope version is rejected as corrupt, not as a '
      'wrong key', () async {
    final raw = base64Decode(await KeyEnvelope.wrap(dek, kek));
    raw[0] = 99;

    expect(
      () => KeyEnvelope.unwrap(base64Encode(raw), kek),
      throwsA(isA<KeyStoreCorrupted>()),
    );
  });

  test('a truncated envelope is rejected as corrupt', () async {
    final raw = base64Decode(await KeyEnvelope.wrap(dek, kek));

    expect(
      () => KeyEnvelope.unwrap(base64Encode(raw.sublist(0, 20)), kek),
      throwsA(isA<KeyStoreCorrupted>()),
    );
  });

  test('a value that is not base64 is rejected as corrupt', () {
    expect(
      () => KeyEnvelope.unwrap('not base64 !!', kek),
      throwsA(isA<KeyStoreCorrupted>()),
    );
  });
}

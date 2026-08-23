import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/crypto/crypto_errors.dart';
import 'package:lev/core/crypto/kek_source.dart';
import 'package:lev/core/crypto/key_manager.dart';
import 'package:lev/core/crypto/key_material.dart';
import 'package:lev/core/crypto/key_record.dart';
import 'package:lev/core/crypto/secure_key_store.dart';
import 'package:lev/core/crypto/secure_storage_kek_source.dart';

import 'in_memory_key_store.dart';

void main() {
  late InMemoryKeyStore store;

  DefaultKeyManager buildKeyManager() => DefaultKeyManager(
        store: store,
        kekSource: SecureStorageKekSource(store),
      );

  setUp(() => store = InMemoryKeyStore());

  group('first run', () {
    test('provisions a 32-byte DEK and stores the KEK and the record',
        () async {
      final dek = await buildKeyManager().obtainDek();

      expect(dek, hasLength(keyLengthBytes));
      expect(store.values, contains(KeyStoreKeys.kek));
      expect(store.values, contains(KeyStoreKeys.record));
    });

    test('the stored record names the secure-storage wrapping mode', () async {
      await buildKeyManager().obtainDek();

      final record = KeyRecord.decode(store.values[KeyStoreKeys.record]!);
      expect(record.wrapping, KeyWrappingMode.secureStorage);
      expect(record.kdf, isNull);
      expect(record.salt, isNull);
    });

    test('the DEK is not stored anywhere in the clear', () async {
      final dek = await buildKeyManager().obtainDek();
      final dekBase64 = base64Encode(dek);

      for (final value in store.values.values) {
        expect(value, isNot(contains(dekBase64)));
      }
    });

    test('two installations do not get the same DEK', () async {
      final first = await buildKeyManager().obtainDek();
      final second = await DefaultKeyManager(
        store: InMemoryKeyStore(),
        kekSource: SecureStorageKekSource(InMemoryKeyStore()),
      ).obtainDek();

      expect(first, isNot(equals(second)));
    });
  });

  group('subsequent runs', () {
    test('return the very same DEK', () async {
      final first = await buildKeyManager().obtainDek();
      // A fresh manager over the same store is what a relaunch looks like.
      final second = await buildKeyManager().obtainDek();

      expect(second, equals(first));
    });

    test('do not rewrite key material', () async {
      await buildKeyManager().obtainDek();
      store.writes.clear();

      await buildKeyManager().obtainDek();

      expect(store.writes, isEmpty);
    });

    test('concurrent callers provision only one DEK', () async {
      final keyManager = buildKeyManager();

      final results = await Future.wait([
        keyManager.obtainDek(),
        keyManager.obtainDek(),
        keyManager.obtainDek(),
      ]);

      expect(results[1], equals(results[0]));
      expect(results[2], equals(results[0]));
      expect(
        store.writes.where((key) => key == KeyStoreKeys.record),
        hasLength(1),
      );
    });

    test('the caller cannot corrupt the cached DEK by wiping its copy',
        () async {
      final keyManager = buildKeyManager();
      final first = await keyManager.obtainDek();
      final expected = Uint8List.fromList(first);

      wipe(first);

      expect(await keyManager.obtainDek(), equals(expected));
    });
  });

  group('inconsistent key material fails loudly', () {
    test('a stored record with no KEK throws and does not re-provision',
        () async {
      await buildKeyManager().obtainDek();
      final record = store.values[KeyStoreKeys.record];
      // What a secure store wiped by an OS restore leaves behind.
      store.values.remove(KeyStoreKeys.kek);
      store.writes.clear();

      await expectLater(
        buildKeyManager().obtainDek(),
        throwsA(
          isA<KeyMaterialMissing>().having(
            (error) => error.missing,
            'missing',
            MissingKeyMaterial.kek,
          ),
        ),
      );
      expect(store.values[KeyStoreKeys.record], equals(record));
      expect(store.writes, isEmpty);
    });

    test('a stored KEK with no record throws', () async {
      await buildKeyManager().obtainDek();
      store.values.remove(KeyStoreKeys.record);

      await expectLater(
        buildKeyManager().obtainDek(),
        throwsA(
          isA<KeyMaterialMissing>().having(
            (error) => error.missing,
            'missing',
            MissingKeyMaterial.wrappedDek,
          ),
        ),
      );
    });

    test('a KEK that no longer opens the record fails authentication',
        () async {
      await buildKeyManager().obtainDek();
      store.values[KeyStoreKeys.kek] =
          base64Encode(Uint8List(keyLengthBytes)..fillRange(0, 32, 7));

      await expectLater(
        buildKeyManager().obtainDek(),
        throwsA(isA<DekUnwrapFailed>()),
      );
    });

    test('a malformed record is corrupt, not absent', () async {
      await buildKeyManager().obtainDek();
      store.values[KeyStoreKeys.record] = 'not json';

      await expectLater(
        buildKeyManager().obtainDek(),
        throwsA(isA<KeyStoreCorrupted>()),
      );
    });

    test('a KEK of the wrong length is corrupt', () async {
      await buildKeyManager().obtainDek();
      store.values[KeyStoreKeys.kek] = base64Encode(Uint8List(16));

      await expectLater(
        buildKeyManager().obtainDek(),
        throwsA(isA<KeyStoreCorrupted>()),
      );
    });
  });

  group('an unavailable secure store', () {
    test('surfaces the failure instead of provisioning over existing data',
        () async {
      await buildKeyManager().obtainDek();
      store.writes.clear();
      store.failOnRead = true;

      await expectLater(
        buildKeyManager().obtainDek(),
        throwsA(isA<KeyStoreUnavailable>()),
      );
      expect(store.writes, isEmpty);
    });

    test('can be retried once the store recovers', () async {
      final expected = await buildKeyManager().obtainDek();
      final keyManager = buildKeyManager();
      store.failOnRead = true;

      await expectLater(
        keyManager.obtainDek(),
        throwsA(isA<KeyStoreUnavailable>()),
      );

      store.failOnRead = false;
      expect(await keyManager.obtainDek(), equals(expected));
    });
  });

  group('currentMode', () {
    test('reports the mode a first run would use before anything is stored',
        () async {
      expect(
        await buildKeyManager().currentMode(),
        KeyWrappingMode.secureStorage,
      );
    });

    test('reports the committed mode once provisioned', () async {
      await buildKeyManager().obtainDek();

      expect(
        await buildKeyManager().currentMode(),
        KeyWrappingMode.secureStorage,
      );
    });
  });

  group('sweepIncompleteRewrap', () {
    test('keeps the KEK the committed mode uses', () async {
      await buildKeyManager().obtainDek();

      await buildKeyManager().sweepIncompleteRewrap();

      expect(store.values, contains(KeyStoreKeys.kek));
    });

    test('drops a KEK left over after a committed switch away from it',
        () async {
      await buildKeyManager().obtainDek();
      final record = KeyRecord.decode(store.values[KeyStoreKeys.record]!);
      // What an interrupted switch to PIN mode leaves: the record committed,
      // the now-unused KEK not yet deleted.
      store.values[KeyStoreKeys.record] = KeyRecord(
        wrapping: KeyWrappingMode.pin,
        wrappedDek: record.wrappedDek,
        createdAt: record.createdAt,
        kdf: 'argon2id',
        salt: base64Encode(Uint8List(16)),
      ).encode();

      await buildKeyManager().sweepIncompleteRewrap();

      expect(store.values, isNot(contains(KeyStoreKeys.kek)));
      expect(store.values, contains(KeyStoreKeys.record));
    });

    test('is a no-op on a fresh install', () async {
      await buildKeyManager().sweepIncompleteRewrap();

      expect(store.values, isEmpty);
    });
  });

  group('toSqlCipherKey', () {
    test('formats the DEK as a raw SQLCipher key literal', () async {
      final dek = await buildKeyManager().obtainDek();

      final key = toSqlCipherKey(dek);
      expect(key, startsWith("x'"));
      expect(key, endsWith("'"));
      expect(key.substring(2, key.length - 1), hasLength(keyLengthBytes * 2));
      expect(key, matches(RegExp(r"^x'[0-9a-f]{64}'$")));
    });

    test('rejects a key of the wrong length', () {
      expect(() => toSqlCipherKey(Uint8List(16)), throwsArgumentError);
    });
  });
}

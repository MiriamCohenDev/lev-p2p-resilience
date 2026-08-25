import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crypto/flutter_secure_key_store.dart';
import '../crypto/kek_source.dart';
import '../crypto/key_manager.dart';
import '../crypto/secure_key_store.dart';
import '../crypto/secure_storage_kek_source.dart';

/// Key-management wiring. Providers are hand-written, per technical-decisions
/// #10 (no `riverpod_generator`).
///
/// The chain is deliberately three links, not one: overriding
/// [secureKeyStoreProvider] alone with an in-memory fake makes the whole module
/// testable without a device, and swapping [kekSourceProvider] is all that
/// enabling PIN mode will take.

/// The OS secure store. The seam tests override.
final secureKeyStoreProvider = Provider<SecureKeyStore>((ref) {
  return FlutterSecureKeyStore();
});

/// Where the KEK comes from. Default mode only — an Argon2-backed source
/// replaces this binding when PIN mode is built.
final kekSourceProvider = Provider<KekSource>((ref) {
  return SecureStorageKekSource(ref.watch(secureKeyStoreProvider));
});

/// The module's entry point for the rest of the app.
final keyManagerProvider = Provider<KeyManager>((ref) {
  final keyManager = DefaultKeyManager(
    store: ref.watch(secureKeyStoreProvider),
    kekSource: ref.watch(kekSourceProvider),
  );
  ref.onDispose(keyManager.dispose);
  return keyManager;
});

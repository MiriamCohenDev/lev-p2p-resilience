# `core/di` — cross-feature wiring

Riverpod providers that bind a **domain interface** to its **data implementation** live here.

The rule (CLAUDE.md, technical-spec §3.4): a feature never imports another feature's
`presentation` or `data`. When one feature needs something another owns, it depends on the
abstract interface in `domain` and gets the implementation from a provider registered here.

Providers that belong to exactly one feature stay inside that feature; only cross-cutting
bindings belong in this folder.

Current and expected occupants:

| Phase | Binding | File |
|---|---|---|
| 1 | `SecureKeyStore`, `KekSource`, `KeyManager` | `crypto_providers.dart` ✅ |
| 1 | `AppDatabase`, repository implementations | — |
| 2 | `LlmService` → llama.cpp binding, `ModelSelector` | — |
| 4 | `TransportService` → no-op stub | — |

Overriding `secureKeyStoreProvider` with an in-memory fake makes the whole
key-management chain testable without a device; see `test/core/crypto/`.

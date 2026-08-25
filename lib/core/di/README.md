# `core/di` — cross-feature wiring

Riverpod providers that bind a **domain interface** to its **data implementation** live here.

The rule (CLAUDE.md, technical-spec §3.4): a feature never imports another feature's
`presentation` or `data`. When one feature needs something another owns, it depends on the
abstract interface in `domain` and gets the implementation from a provider registered here.

Providers that belong to exactly one feature stay inside that feature; only cross-cutting
bindings belong in this folder.

Current and expected occupants (technical-spec §9, build order **v0.2**):

| Phase | Binding | File |
|---|---|---|
| 1 | `SecureKeyStore`, `KekSource`, `KeyManager` | `crypto_providers.dart` ✅ |
| 1 | `AppDatabase` + its file location | `db_providers.dart` ✅ |
| 1 | `ChatRepository` → Drift | `chat_providers.dart` ✅ |
| 2 | `ModelRegistry`, `ModelSelector`, `Tokenizer`, `LlmService` → **`FakeLlmService`** | `llm_providers.dart` ✅ |
| 2 | `SystemPrompt`, `SafetyChecker`, `PromptBuilder`, `ConversationSummariser` | `prompt_providers.dart` ✅ |
| 3.1 | `LlmService` → llama.cpp binding, `Tokenizer` → the engine's own | `llm_providers.dart` |
| 4 | `TransportService` → no-op stub | — |

Note the order. Spec v0.2 inverted Phases 2 and 3, so the chat is built and
finished against a **fake** engine before any native code exists.
`llmServiceProvider` is the single line Phase 3.1 changes — if that swap ever
requires touching anything under `features/chat`, the abstraction has failed and
the fix belongs in the interface, not in the caller.

Overriding `secureKeyStoreProvider` with an in-memory fake makes the whole
key-management chain testable without a device; see `test/core/crypto/`.

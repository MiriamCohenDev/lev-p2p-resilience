# LEV

LEV is an **offline-first, privacy-preserving, cross-platform** application (built with Flutter) with two capabilities: a supportive chat powered by a **local language model**, and **local mutual aid** (posting and fulfilling nearby help requests).

## Specifications — read before developing
The full requirements live in these documents. Read them before implementing anything.

@docs/product-spec.md
@docs/technical-spec.md
@docs/technical-decisions.md


## Non-negotiable rules
These are hard constraints. Violating any of them is a defect, not a trade-off.

- **Fully offline.** No code path may require the network. Any HTTP/socket call to the internet is a bug. There is **no server, no cloud, no external auth, no accounts, no login**.
- **Local encryption.** All user data is stored in an encrypted database (Drift + SQLCipher). Key management uses the hybrid DEK/KEK "key wrapping" scheme described in the technical spec (Section 7). Never write plaintext user data to disk outside the encrypted DB.
- **Privacy.** No telemetry, no analytics, no identity collection. "No login" ≠ "no identifier": any device identity is generated locally on-device (never a server login).
- **Chat has zero dependency on networking.** Keep the Chat feature fully independent of any transport/P2P code.
- **P2P is deferred.** Build the `TransportService` *interface* and register a no-op stub. Do **not** implement real peer-to-peer networking unless explicitly asked — it is a later phase.

## Technology stack (do not substitute without approval)
- **Framework:** Flutter (Dart), targeting Android + Windows + macOS + Linux. Keep code iOS-compatible; iOS is not built in v1.
- **State management:** Riverpod 3.x.
- **Architecture:** Clean Architecture (presentation / domain / data), **feature-first** folders.
- **Database:** Drift (SQLite) + SQLCipher.
- **Local LLM:** llama.cpp via a Dart/FFI binding, running a quantized GGUF model (Qwen, English in v1) behind a multi-model abstraction.
- **Key storage:** flutter_secure_storage + Argon2.
- **Testing:** flutter_test + mocktail.

## Architecture rules
- Dependencies point inward: presentation → domain ← data. The `domain` layer is pure Dart with **abstract interfaces** (`LlmService`, `TransportService`, repositories); `data` provides implementations.
- A feature never imports another feature's `presentation` or `data`. Cross-feature wiring goes through `domain` interfaces registered in `core/di`.
- All persistence goes through repositories — never touch SQL directly from UI or domain.

## Build order
Develop in the phased order defined in the technical spec (Section 9). Do not skip ahead:
1. Project scaffold
2. Storage + security foundation (encrypted DB, key management)
3. LLM integration (llama.cpp, model registry, streaming)
4. Chat feature (end-to-end)
5. Mutual-aid feature (local-only, with transport stub)
6. Packaging + offline distribution (APK, Windows, macOS, Linux)

Later releases (only when asked): iOS support, real P2P BLE-mesh transport, Hebrew model.

## Data model rule
Every shareable entity uses a **UUID** primary key (never auto-increment), carries `createdAt`/`updatedAt` + `originDeviceId`, and uses tombstones (`isDeleted`) instead of hard deletes — so future P2P sync can merge without conflicts. See technical spec Section 6.

## Decisions log
The rationale for every technical decision (and rejected alternatives) is recorded in `docs/technical-decisions.md`. When making a significant new technical decision, append it there with its reasoning.

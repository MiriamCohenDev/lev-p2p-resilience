# LEV — Technical Decisions Log

**Purpose:** every significant technical decision in LEV is recorded here with its rationale and its rejected alternatives. This is the "why" companion to `technical-spec.md` (the "how").

**Rules for this file**

- **Append, never rewrite.** New decisions go at the bottom with the next number. Superseding an old decision means adding a new entry that says so — the old entry stays, marked `Superseded by #N`.
- **Every entry states what was rejected and why.** A decision without rejected alternatives is not a decision, it's a default.
- **Status values:** `Accepted` · `Open` · `Deferred` · `Superseded by #N`

---

## #1 — Platform & framework: Flutter, all platforms

**Status:** Accepted

**Decision.** Build LEV as a single Flutter (Dart) codebase targeting Android + Windows + macOS + Linux. Keep the code iOS-compatible; iOS is not built in v1.

**Rationale.** LEV must run on both phones and computers with feature parity, and the team is one developer. A single codebase across five targets is the only realistic way to reach that scope. Flutter compiles natively on all of them and has a mature FFI story, which matters because both hard dependencies ahead (llama.cpp, SQLCipher) are native libraries.

**Rejected alternatives.**

- *Native per platform (Kotlin + Swift + C#/C++)* — best performance and platform fit, but multiplies the work by four. Not viable for this team size.
- *React Native* — weaker desktop story; desktop is a first-class target here, not an afterthought.
- *Web / PWA* — an earlier iteration of LEV was built this way (React + Transformers.js + WebGPU). Rejected for v1 because the offline-installation requirement (see below) cannot be met by a browser-delivered app, and because native model inference outperforms in-browser inference substantially.

**Consequence.** iOS compatibility is *preserved*, not *delivered*. Any platform-specific code must sit behind an interface so iOS can be added in Phase 6 without redesign.

---

## #2 — Distribution: fully offline, file-transfer based

**Status:** Accepted

**Decision.** LEV is distributed as installable artifacts transferred device-to-device (APK sideload, Windows installer/portable, macOS `.app`/`.dmg`, Linux AppImage). No app stores.

**Rationale.** The product requirement is that *the application itself*, not just its data, can travel between devices with no internet. App stores require connectivity and an account — both are excluded by the product's premise.

**Rejected alternatives.**

- *Google Play / Microsoft Store / Mac App Store* — require network and identity at install time. Directly contradicts the core requirement.

**Consequence — and this is what defers iOS.** iOS does not permit sideloading without a developer account and a signing round-trip, so an offline-distributed iOS build is not possible under this constraint. iOS is deferred to Phase 6, at which point the distribution question must be reopened alongside the native LLM and transport bindings.

---

## #3 — Local LLM: llama.cpp, behind a multi-model abstraction

**Status:** Accepted (Hebrew-model gap remains **Open**)

**Decision.** Run inference with **llama.cpp** via a Dart/FFI binding, loading quantized **GGUF** models. Ship v1 with a single English model (**Qwen**), behind a Model Registry that can select a model by device capability and language.

**Rationale.** llama.cpp is the only inference engine that runs the same quantized model across Android, Windows, macOS and Linux on commodity CPUs, with GPU offload where available. GGUF quantization is what makes a usable model fit on a phone at all. The Model Registry abstraction exists so that adding a Hebrew model, or a larger desktop-tier model, is a registration rather than a rewrite.

**Rejected alternatives.**

- *Cloud LLM API* — excluded by the offline requirement. Not a trade-off; a defect.
- *ONNX Runtime / MediaPipe LLM* — narrower model selection, weaker desktop parity, no GGUF ecosystem.
- *Transformers.js + WebGPU* — used in the earlier PWA iteration. Tied to a browser runtime; rejected together with the PWA approach (#1).

**Known gap — Open.** Small models are weak in Hebrew, and the target audience includes Hebrew speakers for whom the chat's whole value is emotional nuance. v1 ships English-only. Revisit with DictaLM or a multilingual model, likely desktop-tier first (larger quantizations are affordable there). Tracked in technical-spec Section 10.

**Risk.** This is the highest-risk phase in the project: native compilation across four platforms, install size dominated by the bundled model, and inference performance on low-end Android. A feasibility spike before deep investment is advisable.

---

## #4 — Database: Drift (SQLite) + SQLCipher

**Status:** Accepted

**Decision.** Persist all user data in SQLite via **Drift**, with whole-database encryption via **SQLCipher** (`sqlcipher_flutter_libs`). All access goes through repositories — never SQL from UI or domain.

**Rationale.** The data is relational (conversations → messages, requests → commitments) and will eventually need conflict-free merging across devices. SQLite is the most portable, best-understood engine on every target platform; Drift adds type safety and reactive queries; SQLCipher encrypts the entire file transparently, so there is no path by which plaintext user data reaches the disk.

**Rejected alternatives.**

- *Isar / Hive* — maintenance and stability concerns; weaker story for relational data and for cross-device merge.
- *Realm* — sync model is tied to a commercial backend service, which contradicts the no-server premise.
- *ObjectBox* — evaluated seriously and rejected for the same reason: its sync is server-based and commercial.

---

## #5 — Encryption keys: hybrid DEK/KEK key wrapping

**Status:** Accepted

**Decision.** A random **DEK** (Data Encryption Key) is the actual SQLCipher key. The DEK is itself encrypted ("wrapped") by a **KEK** (Key Encryption Key).

- *Default mode (no PIN):* the KEK lives in the OS secure store (`flutter_secure_storage` → Android Keystore / macOS Keychain / platform secure storage). The app opens with no prompt.
- *Optional PIN mode:* the KEK is **derived from the user's PIN via Argon2** and never stored. Maximum privacy; a forgotten PIN means unrecoverable data, because there is no server.

**Rationale.** This is what lets the user turn a PIN on or off without re-encrypting the database — enabling or disabling PIN mode only re-wraps the DEK, an operation on a few bytes rather than on the whole file. It also cleanly separates "what encrypts the data" from "what authorizes the user", which is what makes biometric unlock addable later without touching the storage layer.

**Rejected alternatives.**

- *Derive the SQLCipher key directly from the PIN* — simple, but changing or removing the PIN would require decrypting and re-encrypting the entire database, and biometrics could not be layered on.
- *Store the SQLCipher key in plaintext in secure storage* — no PIN mode possible at all; weaker threat model for a lost or seized device.

**Privacy note.** No accounts, no login, no identity collection, no telemetry, no network calls in v1. "No login" does **not** mean "no identifier": the future P2P layer will generate a **local cryptographic device identity** on-device (the Signal/Briar model), never a server login.

---

## #6 — Architecture: Clean Architecture, feature-first

**Status:** Accepted

**Decision.** Three layers — `presentation` / `domain` / `data` — with dependencies pointing inward (presentation → domain ← data). `domain` is pure Dart holding abstract interfaces (`LlmService`, `TransportService`, repositories); `data` provides the implementations. Folders are organized **feature-first**, not layer-first.

**Rationale.** Two of this project's hardest components — the LLM engine and the future transport — are exactly the things most likely to be swapped. Putting them behind domain interfaces means llama.cpp can be replaced, or a real P2P transport can displace the stub, without touching a single UI file. Feature-first folders keep each capability's code together, which matters more than layer grouping when features are as independent as Chat and Mutual Aid are here.

**Rejected alternatives.**

- *Layer-first folders* — scatters one feature across the tree; painful once there is more than one feature.
- *No formal architecture (pragmatic MVC)* — faster at the start, but the swap-ability above is a hard requirement, not a nicety.

**Hard rule.** A feature never imports another feature's `presentation` or `data`. Cross-feature wiring goes through `domain` interfaces registered in `core/di`.

---

## #7 — State management: Riverpod 3.x

**Status:** Accepted

**Decision.** Use **Riverpod 3.x** for state management and dependency injection.

**Rationale.** Riverpod's dependency-injection story is the deciding factor — the architecture in #6 leans heavily on abstract interfaces resolved at runtime, and Riverpod does that natively with compile-time safety and without a separate DI framework. It also carries far less boilerplate than the alternative, which matters for a solo developer.

**Rejected alternatives.**

- *Bloc / Cubit* — more structured and more conventional in large teams, but heavier in boilerplate, and its DI (`provider`/`get_it`) would be an extra dependency. Rejected on ergonomics, not correctness.
- *GetX* — actively avoided: implicit global state, unclear lifecycles, poor testability.

---

## #8 — P2P transport: deferred, but designed for

**Status:** **Deferred** — implementation deliberately not started

**Decision.** Build the `TransportService` **interface** and register a **no-op stub**. Do not implement real peer-to-peer networking until explicitly scheduled (Phase 6).

**Rationale.** The product requirement is that help requests reach **complete strangers with no shared network** — which rules out Wi-Fi Direct or LAN discovery and forces a **BLE mesh** approach (the Briar / Bridgefy model). BLE mesh is mobile-centric, technically deep, and carries an unresolved threat model. Attempting it before the chat works would risk the whole project on its hardest, least-certain component.

**What is locked in now, so that deferring costs nothing later:**

1. An abstract, feature-independent transport layer — Chat has **zero** dependency on it.
2. A sync-friendly data model: every shareable entity uses a **UUID** primary key (never auto-increment), carries `createdAt` / `updatedAt` / `originDeviceId`, and uses tombstones (`isDeleted`) instead of hard deletes — so a future merge across devices can resolve without conflicts.

**Open consequence.** Mutual-aid sharing may end up mobile-only even though the chat is cross-platform, because BLE mesh is not equally viable on desktop. Unresolved.

---

## Terminology clarified during design

- **"Login"** means authenticating against a server. It is not applicable to LEV — there is no server. What *is* applicable is **local lock** (the optional PIN, #5).
- **"No login" ≠ "no identifier."** The P2P phase will require a locally generated cryptographic identity, in the Signal/Briar sense. Generated on-device, never issued by a server.
- **Offline** in LEV is absolute: no code path may require the network in v1. An HTTP or socket call to the internet is a **bug**, not a trade-off.

---

## Template for new entries

```markdown
## #N — <short title>

**Status:** Accepted | Open | Deferred | Superseded by #M

**Decision.** <what was chosen, in one or two sentences>

**Rationale.** <why — the specific constraint or requirement that forced it>

**Rejected alternatives.**
- *<option>* — <why it lost>

**Consequence.** <what this now commits us to, or forecloses>
```

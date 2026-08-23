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

## #9 — Routing: `go_router`

**Status:** Accepted

**Decision.** Use **`go_router`** for navigation, with the router exposed as a Riverpod `Provider<GoRouter>` (`lib/core/routing/app_router.dart`) rather than as a global. Route paths and names live in a single `AppRoutes` constants class; screens never hardcode route strings. Chat and Tasks are declared as **nested routes under Home**, so each carries a real back stack.

**Rationale.** Phase 0 has to establish routing (technical-spec Section 9) and the spec names no library. `go_router` is the Flutter Team's own package, gives declarative routes that a widget test can drive without a `NavigatorObserver`, and handles the desktop targets (window/deep-link entry points) that are first-class here. Putting the router behind a provider matters specifically for the PIN-lock redirect that #5 anticipates: a lock gate becomes a `redirect` on an overridable provider, not a rewrite of the app root.

**Rejected alternatives.**

- *Plain Navigator 1.0/2.0* — zero extra dependency, which is the argument for it. Rejected because three screens is where the app *starts*, not where it ends: nested flows and the future lock gate would mean hand-rolling exactly what `go_router` provides, and imperative navigation is harder to assert on in tests.

**Consequence.** One dependency outside the stack listed in the technical spec. Navigation is now declarative — adding a screen means adding a `GoRoute` plus an `AppRoutes` constant, not touching the app root.

---

## #10 — Riverpod providers written by hand, not generated

**Status:** Accepted

**Decision.** Declare Riverpod providers manually (`Provider`, `NotifierProvider`, …). Do **not** add `riverpod_generator` / `riverpod_annotation`.

**Rationale.** Codegen buys terseness and some compile-time safety, at the cost of a `build_runner` pass standing between every provider edit and a runnable app. Phase 1 already forces `build_runner` into the project for Drift's table code — where generation is genuinely load-bearing, because the alternative is hand-writing SQL mappers. Provider declarations have no such payoff: they are a handful of lines each, and this project has one developer for whom a slow inner loop is the real cost.

**Rejected alternatives.**

- *`@riverpod` code generation* — less boilerplate and automatic `keepAlive`/family typing. Rejected on inner-loop cost at this project's size, not on correctness.

**Consequence.** Provider declarations are slightly more verbose and `ref.watch` types are written explicitly. Reversible: adopting codegen later is a mechanical, provider-by-provider migration, not an architectural change.

---

## #11 — UI localization (English + Hebrew, RTL) wired from Phase 0

**Status:** Accepted

**Decision.** Set up `flutter_localizations` + ARB files (`lib/core/l10n/app_en.arb`, `app_he.arb`, `l10n.yaml`) in Phase 0. Every user-visible string is keyed from the first screen onward; no literal strings in widgets. Locale follows the device.

**Rationale.** Technical-spec Section 8 requires the **UI** to support English and Hebrew including RTL. Retrofitting i18n is one of the few tasks that gets strictly more expensive with every screen added — it means revisiting every widget already written — and RTL breaks layout in ways that only appear when actually rendered RTL. Doing it at Phase 0 costs almost nothing (three screens) and turns "does it work in Hebrew?" into a test that runs from day one rather than a discovery made in Phase 5.

**Rejected alternatives.**

- *Defer i18n to a later phase* — faster Phase 0. Rejected: it front-loads no risk and back-loads a sweep across every screen plus an unknown pile of RTL layout defects.

**Consequence — do not confuse this with #3.** This decision covers the **interface only**. The **model** remains English-only in v1; the Hebrew-model gap in #3 is untouched and still Open. A Hebrew-reading user gets a Hebrew UI and an English assistant.

---

## #12 — Key-management storage layout: one record is the commit point

**Status:** Accepted

**Decision.** The DEK/KEK scheme of #5 is implemented with exactly two entries in
`flutter_secure_storage`:

- `lev.kek.v1` — the raw KEK, present only while the KEK is the stored kind.
- `lev.keystate.v1` — a JSON record holding the **wrapped DEK** together with the
  wrapping mode, and `kdf`/`salt` fields reserved for PIN mode.

Wrapping is AES-256-GCM from **`cryptography_plus`**, in an envelope of
`version(1) ‖ nonce(12) ‖ ciphertext ‖ mac(16)`. The KEK is reached through an
abstract `KekSource`; only the secure-storage implementation exists.

Any read failure raises a typed exception. New key material is provisioned
**only** when the store cleanly reports that nothing is there.

**Rationale.** Putting the wrapped DEK inside the same record as the wrapping
mode is what makes #5's promise — that toggling a PIN only re-wraps — survive a
crash. A future switch is: derive the new KEK, wrap the same DEK, **write the
record once**, then drop the KEK the old mode used. That single write is the
commit point. Interrupted before it, the old record and old KEK are both intact;
interrupted after it, the new record is authoritative and the stale KEK is
removed by `sweepIncompleteRewrap()` on the next launch. There is no ordering in
which no valid wrapping exists.

The fail-closed rule is the other half. `flutter_secure_storage` throws rather
than returning null when the OS store is unreachable — a missing libsecret or a
locked keyring on Linux, a Keystore error on Android. Reading such a failure as
"first run" would provision a fresh DEK on top of an existing encrypted
database and destroy it silently. With no server and no backup, that is
unrecoverable, so "absent" and "failed" are kept structurally distinct all the
way down.

Android auto-backup is disabled in the manifest for the same reason: it
contradicts the no-cloud rule, and restoring secure-storage entries onto a
different device yields a KEK the Keystore cannot unwrap.

**Rejected alternatives.**

- *A separate `lev.dek.v1` entry plus a metadata pointer* — the layout this
  started as. Rejected: committing a mode switch then meant writing two entries,
  and a crash between them left a state where neither entry could be identified
  as the live one without embedding the mode in the envelope anyway.
- *A `pending` scratch slot for the in-progress re-wrap* — unnecessary once the
  record itself is atomic, and actively harmful: after a commit the pending blob
  is the *winner*, so a naive startup sweep that deletes it destroys data.
- *`pointycastle`* — battle-tested and equally capable (`GCMBlockCipher` +
  `Argon2BytesGenerator`), but a markedly lower-level API for the same result.
  Kept as the fallback if `cryptography_plus` stops being maintained.
- *Storing the SQLCipher key directly, without wrapping* — already rejected in
  #5; restated here because in default mode the two look deceptively similar.

**Consequence.** PIN mode becomes a new `KekSource` plus a re-wrap routine that
writes one record — no schema change, no migration, no re-encryption. Callers of
`KeyManager` must handle `KeyManagementException`; in particular
`KeyMaterialMissing` is a real state that Phase 1's database step has to decide
about, since only that layer can tell whether a database file exists.

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

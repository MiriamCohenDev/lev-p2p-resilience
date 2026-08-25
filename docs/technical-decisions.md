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

## #13 — SQLCipher comes from `package:sqlite3` build hooks, and the build is verified at runtime

**Status:** Accepted

**Decision.** Three parts, and the third is the one that matters most.

1. **Source.** SQLCipher is selected in `pubspec.yaml` rather than by a plugin
   dependency:

   ```yaml
   hooks:
     user_defines:
       sqlite3:
         source: sqlcipher
   ```

   `sqlcipher_flutter_libs` — named in technical-spec Section 4 and Appendix A —
   is **not** used. Nothing calls `open.overrideFor`, and there is no
   per-platform configuration.

2. **Fail closed.** `openEncryptedDatabase` obtains the DEK *before* touching the
   filesystem, so a key failure leaves the disk untouched by construction. Each
   `KeyManagementException` is translated into a `DatabaseOpenException` that
   states whether a database file was at stake. No database file is ever opened,
   created, or deleted without a valid DEK, and there is never a fallback to an
   unencrypted database.

3. **`PRAGMA cipher_version` is asserted on every open.** If it returns nothing,
   the open fails with `DatabaseNotEncrypted`.

**Rationale.**

*On (1)* — the named package is end-of-life, not merely dated. Its last release
is `0.7.0+eol` (2026-02-15) whose own description reads *"Not used anymore,
update to version 3.x of package:sqlite3 instead"*; `UPGRADING_TO_V3.md` in
`simolus3/sqlite3.dart` says *"If you depend on `sqlcipher_flutter_libs`, stop
doing that… `sqlcipher_flutter_libs` is no longer functional"*; and its directory
has been removed from the repository's main branch. This is not third-party
abandonment — simolus3 maintains drift, `package:sqlite3` and the retired package
alike. From `package:sqlite3` 3.x the native library is built through Dart build
hooks instead of a Flutter plugin, and `drift 2.34.3` depends on `sqlite3:
^3.4.0`, so any current drift is already in that world. Staying on the spec's
literal wording would mean pinning drift to a pre-3.x release permanently.

*On (3)* — this is the guard the entire encryption-at-rest claim rests on. Plain
SQLite does not reject `PRAGMA key`; it **ignores it silently** and creates an
ordinary plaintext database. A build whose hook configuration failed to apply
would therefore look completely healthy — the app opens, writes and reads
normally — while putting every conversation and help request on disk in the
clear, which CLAUDE.md rules out absolutely. `PRAGMA cipher_version` returns no
rows on plain SQLite and the cipher's version on SQLCipher, so one statement at
open time turns a silent catastrophe into a loud startup failure. This was
verified by deliberately building with `source: sqlite3`: the open aborts with
`DatabaseNotEncrypted` and leaves a zero-byte file — no user data reaches disk.

*On (2)* — this answers the question #12 explicitly deferred to this layer. Only
storage can see whether a database file exists, and that is exactly what decides
severity: `KeyMaterialMissing(wrappedDek)` with no file on disk is a resettable
installation, while the same key state *with* a file is unrecoverable data loss.
`DatabaseKeyLost` carries `databaseFileExists` so a caller can tell the two
apart. Resetting is destructive and needs the user's consent, so it is **not**
performed here — the failure is reported and the disk is left alone.

**Rejected alternatives.**

- *Pin `sqlcipher_flutter_libs` 0.6.8 (its last functional release) plus a
  pre-3.x drift* — keeps the spec's literal wording and works today. Rejected:
  it freezes the storage layer on code the maintainer has already retired, and
  reintroduces the manual `open.overrideFor` wiring per platform that the hook
  removes.
- *Trusting the build configuration without the `cipher_version` assertion* —
  one less statement per open. Rejected outright: the failure mode is silent
  plaintext, which is unacceptable at any price in statements.
- *Automatically resetting the installation when the key record is gone and no
  database file exists* — technically safe in that exact state. Rejected because
  the storage layer cannot ask the user, and a rule of "sometimes we delete key
  material on startup" is one misjudged condition away from destroying data with
  no server and no backup to recover from.

**Consequence — three things this commits us to.**

- The build hook **downloads the SQLCipher binary from the network at build
  time**. This does not violate LEV's offline rule, which governs *runtime*
  (`flutter pub get` already needs a network), but a fully reproducible offline
  build needs the `url_pattern` user-define pointed at an internal mirror. Open
  for Phase 5.
- The SQLCipher build **links OpenSSL on Windows, Linux and Android**, and per
  its documentation "may include an older SQLite version than the default build".
  Both matter for packaging and licensing in Phase 5.
- `PRAGMA key` takes the raw key as a **quoted string** — `PRAGMA key = "x'…'";`.
  Passing the blob literal unquoted is a syntax error. Related: the hex form of
  the DEK is a Dart `String` and therefore cannot be wiped from memory; the byte
  array is wiped, the string is not. That is inherent to the `PRAGMA key` API.

**Verified on device.** `integration_test/encrypted_storage_test.dart` runs the
unsubstituted chain — OS secure store → KEK → wrapped DEK → SQLCipher — on both
Android and Windows, and confirms that a second launch unwraps the *same* DEK
rather than quietly provisioning a new one. Three findings worth keeping:

- The hook produces `libsqlcipher.so` for **all three Android ABIs**
  (`arm64-v8a` 4.85 MB, `armeabi-v7a` 3.91 MB, `x86_64` 5.67 MB). No `minSdk`
  raise was needed — `flutter.minSdkVersion` suffices. The per-ABI cost is small
  next to the bundled model but belongs in the Phase 5 size budget.
- Runtime is proven on `x86_64` (emulator) and Windows. The arm64 binary is
  *built* but has not been *run*; a physical-device check is still outstanding.
- Checking an encrypted file by trying to open it with plain SQLite is
  **vacuous on a zero-byte file** — Python's `sqlite3` treats an empty file as a
  new database and reports success. Any such check must assert the file is
  non-empty first.

---

## #14 — Chat schema: §6.1 literally, timestamps as text, and the probe retired

**Status:** Accepted

**Decision.** `lev.db` at `schemaVersion 1` holds two tables, `conversations` and
`messages`, with exactly the columns technical-spec §6.1 lists — **no
`originDeviceId`, no `isDeleted`**. Timestamps are stored as ISO-8601 **text**,
not as unix seconds. `PRAGMA foreign_keys = ON` is set on every connection.
`ChatRepository` sits in `features/chat/domain`; the Drift implementation and the
row→entity mapping sit in `features/chat/data`. The `lev_probe.db` scaffolding
from #13 is deleted.

**Rationale.**

*On the missing sync columns.* CLAUDE.md states the rule categorically — "Every
shareable entity uses a UUID primary key, carries `createdAt`/`updatedAt` +
`originDeviceId`, and uses tombstones". Its precondition is **shareable**, and
chat is not: §3.1 makes zero dependency on networking the single most important
architectural constraint, and §2.2 puts cross-device sync out of scope entirely.
§6.1 reflects exactly that — it lists those columns for `HelpRequest` and
`HelpCommitment` and omits them for `Conversation` and `Message`. The decisive
practical point: `DeviceIdentity` is itself marked Phase 2 in §6.1 and does not
exist, so an `originDeviceId` column could only be filled with a placeholder.
A column that can hold nothing true is worse than no column.

*On text timestamps.* Drift's default stores a `DateTime` as unix **seconds**,
truncating everything finer. In a streaming chat a user's message and the
assistant's reply routinely land inside the same second, and `ORDER BY createdAt`
would then return them in an order SQLite is free to vary between reads — a
conversation that reshuffles itself. This was not theoretical: three repository
tests failed on it before the option was set. Text keeps sub-second precision and
still sorts correctly as a string. Decided at `schemaVersion 1` because changing
it later means rewriting every stored timestamp.

*On foreign keys.* SQLite ignores foreign keys unless enabled, per connection.
Without the pragma the `references` declaration is a comment, and an orphaned
message — one whose conversation was deleted — would be accepted silently. It is
set in `encrypted_database_opener.dart` beside `PRAGMA key`, and both the host
tests and the repository tests assert that an orphan insert is rejected.

**Rejected alternatives.**

- *Apply CLAUDE.md's rule uniformly, including to chat* — consistent, and cheap
  insurance if chat is ever synced. Rejected: it writes a placeholder device id
  for a device identity that will not exist until Phase 2, and contradicts the
  explicit table in §6.1. If chat ever becomes shareable, adding the columns is a
  migration — the same migration this would be paying for now, only without
  knowing what to put in them.
- *Both help tables in schema 1 as well* — one schema, no migration to write in
  Phase 4. Rejected in favour of shipping what Phase 3 needs; the mutual-aid
  tables arrive as schema **2**, and `drift_schemas/drift_schema_v1.json` is
  committed so that migration can be tested rather than hoped about.
- *Keeping `lev_probe.db` as a standing smoke test* — the original intent in #13.
  Rejected once the on-device tests existed: proving encryption against the real
  database is strictly stronger than proving it against a scratch table, and a
  second SQLCipher file opened on every launch is cost without benefit. The
  encryption checks now write a real `Message` through the real repository, so
  what the byte-level audit examines is user data in its actual shape.
- *`ChatRepository` exactly as §5.1 sketches it* — two methods. Rejected: that
  sketch is marked illustrative and cannot stand alone, because a message cannot
  be appended to a conversation that does not exist and the foreign key now
  enforces it. `createConversation` and `watchConversations` were added;
  `watchConversation` was renamed `watchMessages`, since it returns messages.
  Nothing else was added — product-spec §5 lists no conversation-management
  action, so there is no delete or rename.

**Consequence.**

- The Dart getter for the message body is `body`, not `text`: `text` is drift's
  own column-builder method on `Table` and cannot be shadowed. `named('text')`
  keeps §6.1's column name on disk, and the domain entity restores `Message.text`
  — the name collision is confined to the row class.
- Drift row classes are `ConversationRow` / `MessageRow` (via `@DataClassName`)
  so the domain entities can own `Conversation` and `Message` without prefixed
  imports anywhere.
- Verified end to end: a conversation and message written through
  `ChatRepository` survive a close and reopen on Android and Windows, and the
  file pulled off the device shows random salt, no canary, **and no table names**
  — the schema itself is inside the encryption — with plain SQLite refusing it.

---

## #15 — Chat schema realigned to technical-spec v0.2, in place at `schemaVersion 1`

**Status:** Accepted — supersedes the schema half of #14

**Decision.** The chat schema now matches technical-spec v0.2 §6.1 field for field,
changed **in place at `schemaVersion 1`** rather than migrated to schema 2:

- `Messages.fromUser` (boolean) → `Messages.role` (text: `user` | `assistant` |
  `system`). The vocabulary is owned by `MessageRole.wireName` in the domain, and
  the column stays a plain text column rather than a drift enum converter so that
  an unrecognised value fails loudly in one place with a `FormatException`.
- `Conversations` gains `summary`, `summaryUpToMessageId`, `systemPromptVersion`,
  `modelId` and `isDeleted`.
- `ChatRepository` gains `deleteConversation`, `saveSummary`, `findConversation`
  and `messagesOf`.
- An index on `messages (conversation_id, created_at)` — the one query the chat
  runs constantly.
- `build.yaml` sets `store_date_time_values_as_text: true` for the generator, so
  `drift_schemas/drift_schema_v1.json` stops disagreeing with
  `AppDatabase.options`.

**Rationale.** Spec §6 names the deadline explicitly: *"Fixing this before Phase
2.2 is a schema definition; fixing it afterwards is an encrypted-database
migration across four platforms."* #14 was decided against spec **v0.1**, which
had no prompt layer, no rolling summary and no conversation management; v0.2
added all three, and §6.1 now lists these columns. Phase 1 was merged but never
released, so no database exists anywhere that a migration could migrate.

The boolean could not survive in any case: §5.2.2's chat templates map roles to
model-specific markers, and a two-valued field cannot express `system`.

**Rejected alternatives.**

- *Migrate to `schemaVersion 2`* — the cautious-looking option. Rejected: there
  is no shipped database, so `onUpgrade` would be unreachable code written to
  reassure rather than to run, and it would permanently enshrine a v0.1 schema as
  the project's version 1.
- *A drift enum converter (`intEnum` / `textEnum`) for `role`* — less code.
  Rejected: it stores the enum's Dart identifier, so renaming a Dart constant
  silently rewrites the meaning of rows already on disk, and the failure mode for
  an unknown value is a generated exception far from anything that can explain it.
- *Keeping `Message` tombstoned like `Conversation`* — §6.1 gives `Message` no
  `isDeleted` field, so this is not available without inventing schema.

**Consequence — the two halves of a delete.** `deleteConversation` tombstones the
conversation row and **erases** its messages and summary, in one transaction.
This is §6.1 read literally (only `Conversation` has `isDeleted`) and it is the
only reading a privacy product can defend: a "delete" that leaves every word of
the conversation on disk is a lie, and #4's whole-database encryption protects
against a stolen device, not against the app itself retaining what the user told
it to destroy. The row survives as a marker for a future P2P merge; the content
does not.

**Consequence — one naming deviation, deliberate.** §5.1's illustrative sketch
calls the message stream `watchConversation`; the interface keeps Phase 1's
`watchMessages`, because a method named for a conversation that returns a list of
messages reads backwards at every call site. Every other member matches the
sketch. Recorded here so the difference is a decision rather than a drift.

---

## #16 — LLM contracts: interfaces in the chat domain, `ModelDescriptor` in `lib/llm/`

**Status:** Accepted

**Decision.** The Phase 2.1 contracts are split across two places, and the split
is not arbitrary:

- `features/chat/domain/` holds `LlmService`, `LlmSession`, `Prompt`,
  `Tokenizer`, `PromptBuilder`, `SafetyChecker` and a sealed `LlmException`
  hierarchy — the things the chat *talks to*.
- `lib/llm/` holds `ModelDescriptor`, `ModelRegistry` and `ModelSelector` — the
  things that describe *which model*, loaded from `assets/models/models.json`.

The chat domain imports `lib/llm/model_descriptor.dart`. That is allowed:
`lib/llm/` is shared infrastructure rather than a feature, so §3.4's "a feature
never imports another feature's `presentation` or `data`" does not apply, and
`ModelDescriptor` is pure Dart config with no framework or platform dependency,
so §3.2's inward-pointing rule is intact.

**Rationale.** §3.4 assigns these folders directly, and §5.3 puts the descriptor
with the registry. The deeper reason is that the two have different lifetimes: the
interfaces are code that changes when the *chat* changes, while the registry is
**data** that changes when a *model* is added. §5.3 requires adding a model to be
a manifest entry plus a GGUF file with no change under `features/chat`, and
Phase 3.3 exists to verify exactly that. Putting descriptors in the chat feature
would make the first Hebrew model a code change in the feature the claim is about.

**Rejected alternatives.**

- *`ModelDescriptor` in `features/chat/domain/`* — removes the cross-directory
  import and looks tidier. Rejected: it makes the chat feature the owner of model
  configuration, which is the coupling §5.3 and Phase 3.3 are designed to prevent.
- *A drift-style enum for `ModelDescriptor.family`* — type safety for free.
  Rejected for the same reason: a new family would then be a Dart edit, when the
  whole point is that it is a manifest edit. An unknown family fails when a
  template is requested for it, which is where the failure is actionable.
- *Letting `LlmService` take `List<Message>` and format internally* — the v0.1
  shape. Rejected in spec v0.2 §4 and restated here: an engine that formats raw
  history must know every model's conventions, so a model swap becomes an engine
  rewrite.

**Consequence — the fake is a product decision, not a test double.**
`FakeLlmService` ships in `features/chat/data/` beside the real implementation,
not in `test/`. §9's Phase 2 is built and *finished* against it, so its failure
modes (`failBeforeFirstToken`, `failMidGeneration`, `stall`, and a configurable
prefill delay) are the states the Phase 2.2 UI is written for. Two behaviours are
load-bearing and are asserted directly:

1. **Cancelling a subscription stops generation**, not merely delivery. A
   producer that keeps running behind a dropped stream holds the model busy and
   burns the battery §8 asks us to watch.
2. **A stall leaves the stream open.** An early implementation closed it through
   a `finally`, which delivers a done event — the one thing a stalled engine does
   not do. A UI validated against that would have looked correct in tests and
   hung in front of a user.

`deviceRamMbProvider` reports a value that admits every model for now; §9's
Phase 3.2 replaces that binding with a real measurement, which is the first phase
where a model is loaded and the number means anything.

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

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

**Status:** Accepted — the nesting half **superseded by #22**

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

## #17 — Context policy: one fitting function, and a summary written after the turn

**Status:** Accepted

**Decision.** `DefaultPromptBuilder` implements §5.2.3's three-tier budget —
system prompt, then rolling summary, then as many trailing turns as fit — and
exposes a third method beyond §5.1's sketch, `overflow`, returning the oldest
turns that no longer fit. Both `buildSeed` and `overflow` are thin wrappers over
**one private fitting function**. Summarisation runs *after* a turn is on screen,
in a session of its own, and its result is capped before it is persisted.

**Rationale.**

*One fitting function.* §5.2.3 requires the turns that fall out of the window to
be folded into the summary, so something has to decide which turns those are.
Computing it in a second place would eventually disagree with the prompt — and
the two failure modes are both silent: a turn in neither is lost outright, and a
turn in both is summarised while still being carried verbatim. A test asserts the
two agree exactly.

*A session of its own.* Sending the summarisation instruction through the
conversation's live session would write it into the KV cache that session exists
to protect — the instruction and its output would become part of the conversation
the model believes it is having.

*After the turn, not before the next one.* Summarising is a second generation. In
front of the user it would stall the conversation for the one thing they cannot
see the point of, so it happens once the reply is already on screen. A failure is
swallowed: the same turns are offered again next time, which costs a call, not a
conversation.

*The cap.* §5.2.3 says "capped at a fixed token length" and that cap is the whole
point — an uncapped summary grows with the conversation and eventually consumes
the budget it was introduced to bound. It is trimmed by whole sentences, because
a summary cut mid-clause reads as though the conversation was cut off there, and
the model is being asked to treat it as fact.

**Rejected alternatives.**

- *Keep `PromptBuilder` at exactly §5.1's two methods and compute the overflow in
  the notifier* — matches the sketch. Rejected: it puts the budget in two places,
  and §5.1's code block is explicitly illustrative.
- *Summarise before assembling the next prompt* — one less method and no stale
  window. Rejected on latency: it puts a full generation in front of the user's
  next message.
- *A fixed "last N turns" window instead of a token budget* — far simpler.
  Rejected: N that is safe on the smallest model wastes most of the largest one's
  window, and §8 makes overflowing a defect rather than something to approximate.

**Consequence — an over-budget prompt is a loud failure.** If the system prompt
alone cannot fit the model's window, `buildSeed` throws `ModelUnavailable` naming
both. §8 makes exceeding the budget a defect: the engine's response is to
silently truncate the system prompt, which removes the assistant's stated limits
while leaving it sounding exactly as confident. Refusing beats answering without
them.

---

## #18 — The safety layer follows the person, and never replaces the reply

**Status:** Accepted — the presentation half **superseded by #24**

**Decision.** `AssetSafetyChecker` matches the user's raw message against
`assets/prompts/safety_patterns_<locale>.json` **before** it reaches the model.
On a match the UI shows a fixed support message **alongside** the reply. The
locale is the **UI** locale, not the model's. A language with no pattern file
gets `NeverMatchingSafetyChecker`. A corpus of positive *and negative* cases
covers both shipped locales.

**Rationale.**

*Deterministic.* §5.2.4's argument, restated: a guarantee that depends on the
inference quality of a 4-bit model running on an old phone is not a guarantee.
Nothing in this layer consults a model, so the corpus passes whichever engine is
registered — which is the strongest form of that requirement, not merely a test
of it.

*Alongside, never instead.* Replacing the answer with a canned notice teaches a
person in distress that saying the wrong thing gets them shut out of the
conversation. The message is stored and answered like any other.

*The UI locale.* §10's Hebrew gap and #11 together mean a Hebrew-reading user gets
a Hebrew UI and an English assistant. The person still writes in Hebrew, so the
patterns that must catch them are Hebrew — following the model's language here
would leave exactly the users #11 exists for uncovered. The locale is read from
the widget tree, the only place it is actually known.

*Negative cases carry as much weight as positive ones.* "Work is killing me" and
"I could die of embarrassment" must not fire. A layer that goes off on every hard
day is one people learn to scroll past within a week — at which point it looks
like care while functioning as noise, which is worse than absent.

**Rejected alternatives.**

- *Ask the model to classify the message* — better recall, and unusable here for
  the reason above. It also puts the distressed message through a second
  generation before the user sees anything.
- *Patterns in Dart source* — no asset loading, no parse failures. Rejected:
  §5.2.4 requires a localisable list, and tuning it would then mean a rebuild.
- *Fail closed when a locale has no pattern file* — safer-sounding. Rejected: the
  notice is supplementary, the model still answers, and taking the chat down over
  a missing list helps nobody. Both shipped locales are covered by the corpus, so
  this is a fallback for a language nobody has written patterns for yet, not an
  accepted state.

**Consequence.** Adding a language means an asset file, a corpus entry and an
entry in `safetyLocales` — no code change. Widget tests substitute the pattern
list rather than loading it: `rootBundle` caches the `Future` it returns, and a
cached asset future does not resolve again inside a later test's `fake_async`
zone, so the first test in a file would load it and every test after would hang
waiting on it. The real assets are parsed and checked in their own test files.

---

## #19 — The llama.cpp binding is `llamadart`, and the weights are not in git

**Status:** Accepted

**Decision.** Three parts.

1. **The binding is `llamadart`**, not either package technical-spec §4 and
   Appendix A name. Native llama.cpp binaries are resolved by its Dart **build
   hook** — the same mechanism SQLCipher already arrives through (#13) — so there
   is no C++ toolchain and no per-platform plugin wiring. The hook is restricted
   in `pubspec.yaml` to the llama.cpp runtime only:

   ```yaml
   hooks:
     user_defines:
       llamadart:
         llamadart_native_runtimes: llama_cpp
   ```

2. **The GGUF is not committed.** `assets/models/*.gguf` is gitignored. The
   manifest is the source of truth: it names the file, pins its `sha256`, and
   carries a `sourceUrl` that **only** `tool/fetch_model.dart` reads.
   `ModelDescriptor` has no `sourceUrl` field, so no code under `lib/` can reach
   it even by accident.

3. **`InstalledModelFileStore` resolves weights to a real file**, checking the
   digest (§7.5) before llama.cpp sees them: an installed copy in the app support
   directory first, the bundled asset extracted once otherwise, and a typed
   failure if neither exists.

**Rationale.**

*On the binding.* §4 says to "evaluate current maintenance at Phase 2 start", and
the evaluation disqualified both names. The published `fllama` is `0.0.1`, 21
months old, Android/iOS only, from an unverified uploader — and desktop is a
first-class target here, not an afterthought. `llama_cpp_dart` is real and
maintained, but ships **no binaries**: adopting it means building llama.cpp for
Android, Windows, macOS and Linux and owning those artifacts, which is precisely
the "riskiest, most environment-dependent part of the build" §9 reordered the
phases to contain. `llamadart` was released five days before this decision,
covers all four targets plus iOS, and — decisively — resolves binaries through
build hooks, so the project acquires no second native-build story. Its API
covers every contract Phase 2 wrote against without adaptation: raw-prompt
`generate` (so the chat keeps owning its own templates, #16), `stopSequences`,
`cancelGeneration`, `getTokenCount`, and `reusePromptPrefix` for KV reuse.

*On the runtime restriction.* Measured, not assumed. An unrestricted build
emitted **~165 MB** of native libraries on Windows, of which ~75 MB was LiteRT-LM
and a WebGPU/Dawn stack that LEV never calls — §3 names llama.cpp as the engine
and §8 makes install size a budget. With the define, the same build emits ~56 MB.
Verified by deleting the LiteRT DLLs and rebuilding: they do not come back.

*On keeping weights out of git.* Hundreds of megabytes of binary that git cannot
diff, that every clone pays for again, and that every branch switch rewrites.
The digest in the manifest is what makes the file's absence safe: what matters
for correctness is not that the bytes are in the repository but that the bytes on
disk are provably the right ones, and §7.5 already requires exactly that check.

*On the file store.* llama.cpp opens (and prefers to `mmap`) a filesystem path,
and a Flutter asset is not a file — on Android it is an entry inside the APK.
Something has to place the weights, verify them, and do it once. Extraction is
written to a `.part` file and renamed, because a rename is atomic on every target
platform: a file at the real path is therefore always complete, and a crash
mid-extraction cannot leave a truncated file that fails its digest forever with
nothing able to repair it. The same path serves the sideload case — a user who
cannot take a 2 GB installer drops the GGUF in the directory and it is picked up,
having passed the identical check.

**Rejected alternatives.**

- *`llama_cpp_dart`, as the spec's Appendix A suggests* — closest to the written
  word, and genuinely maintained. Rejected on the binaries: four cross-compiled
  native builds to own and re-cut on every llama.cpp bump, for one developer.
- *A custom `dart:ffi` layer*, which §4 permits "only if bindings prove
  inadequate" — they did not prove inadequate. Rejected as weeks of work to
  reach a worse version of what the hook already delivers.
- *Committing the GGUF* — one fewer setup step, and the repository is then
  self-contained. Rejected on repository weight, and it does not even buy
  integrity: a committed file still has to be checked, because the threat §7.5
  names is corruption and tampering on the user's disk, not in git.
- *Downloading the model at first run from inside the app* — the smoothest
  onboarding by a distance. **Rejected outright**: §8 makes a runtime network
  call a defect, not a trade-off, and this is the single most tempting place in
  the project to breach that. The `sourceUrl`/`ModelDescriptor` split exists so
  the temptation is not merely resisted but structurally unavailable.
- *Loading the GGUF straight from the asset bundle* — no extraction, no second
  copy on disk. Not possible: llama.cpp needs a path, and on Android there is
  none.

**Consequence — four things, and the first is a live gap.**

- **Fetching the weights needed a network exception, and the obvious diagnosis
  was wrong.** The machine runs a NetFree content filter, and `huggingface.co`
  is **not** blocked — a `config.json` fetches normally, which is why nothing
  looked blocked in the filter's settings. What is blocked is the CDN every
  large file redirects to: `us.aws.cdn.hf.co`, returning `HTTP 418` with
  `"block":"risk-type"`. Host-based, not extension-based — a `.safetensors` is
  refused exactly like a `.gguf`, while an 18 MB `.zip` from GitHub Releases
  downloads fine. That last fact is why the llama.cpp binaries resolve and the
  build works at all. The Ollama registry is blocked too. The GGUF was
  ultimately brought in by hand and verified against the pin.
- **The digest is pinned even though the file was never downloaded.** HuggingFace
  serves the LFS pointer as ordinary text at the `raw` endpoint — outside the
  blocked CDN — and it carries `oid sha256:` and `size` for the object. Those
  were read directly and cross-checked against the `X-Linked-ETag` and
  `X-Linked-Size` headers on the blocked request; all four agree
  (`6eb923e7…8653`, 397 808 192 bytes).

  This is a better position than pinning after a download, not a worse one: the
  digest arrives over a different channel from the bytes it will authenticate,
  so §7.5's check actually verifies the transfer rather than merely restating it.
  Hashing whatever happened to land on disk and calling that the pin would have
  authenticated nothing.
- `ggml-vulkan.dll` (35.6 MB) is still emitted. Kept deliberately: GPU offload is
  a real desktop win and §8 asks about performance as well as size. Trimming it
  via `llamadart_native_backends` is a Phase 5 packaging call.
- Like #13's hook, this one **downloads at build time**. Same conclusion: it does
  not breach the offline rule, which governs runtime, but a reproducible offline
  build needs a mirror. Now two hooks need that in Phase 5, not one.

**Verified on device.** `integration_test/llm_generation_test.dart` runs the
unsubstituted chain on Windows — manifest → selector → integrity check → llama.cpp
→ streamed tokens — with the real Qwen2.5-0.5B-Instruct Q4_K_M weights. All four
cases pass. Three findings worth keeping:

- **The session's transcript works.** Told "My name is Dana", then asked "What is
  my name?" in a second turn, the model answers *Dana*. That is the whole of
  §5.1's session contract passing end to end: the reply and its `assistantSuffix`
  are folded back into the transcript, and `reusePromptPrefix` matches it against
  the KV cache. The second turn cost **373 ms against the first turn's 9 188 ms**
  — a factor of 25, which is the cache being hit rather than the conversation
  being re-ingested. Had either half been wrong, this test would answer with a
  guess and every turn would cost the first turn's price.
- **Cancellation reaches the decode loop**, not merely the stream. Verified
  against the real engine: after cancelling, token production stops.
- **First-token latency is 6.1 s, and that is the open number.** A ~2.2 KB system
  prompt prefilled on CPU, in a debug build, for a 0.5B model. It is not a defect
  — it is the first real measurement §8's "first-token latency per tier" has to
  be set from, and it will be worse on Android. **Open for Phase 5: measure in
  release, on a physical arm64 device, and decide the tiers.** The obvious levers
  if it needs them are GPU offload (`ggml-vulkan` is already shipped) and
  shortening the system prompt.

**Still outstanding.** Android has not been run — the same test is written to run
there unchanged, and #13's note that the arm64 SQLCipher binary is built but
never executed now applies to llama.cpp as well.

---

## #20 — The tokenizer stays synchronous, and is calibrated against the model

**Status:** Accepted — refines the Phase 3.1 promise in #16 and `tokenizer.dart`

**Decision.** `Tokenizer.count` remains **synchronous**. Phase 3 does not replace
it with llama.cpp's tokenizer directly; it introduces `CalibratedTokenizer`,
which uses the engine's real tokenizer **once, at model load**, to measure that
model's characters-per-token, and then counts synchronously against the measured
ratio. The measurement takes the **worst** ratio across the samples, shades it
further by a 10% margin, and is never allowed above the old constant of 3.5.
Failure to calibrate falls back to that constant.

**Rationale.** Three sentences in the codebase promised that Phase 3.1 would swap
in "the engine's own tokenizer". Attempting it revealed why that promise could
not be kept literally: llama.cpp's tokenizer is reachable only **asynchronously**
(llamadart runs it on a worker isolate), while `count` is synchronous — and
`DefaultPromptBuilder._fit` calls it **once per message** while deciding what
fits. An async tokenizer therefore means one isolate round-trip per message on
every single turn, to answer a question whose useful precision is only "does this
still fit". Making the whole prompt layer async to buy that would slow every turn
in proportion to the length of the conversation, which is the exact cost #17's
session design exists to avoid.

Calibration keeps what the exact tokenizer was actually wanted for. The old
constant was English prose's average, not the loaded model's — and §10's Hebrew
gap is where that bites: Hebrew runs closer to two characters per token on a Qwen
vocabulary, where 3.5 would under-count by nearly half. §8 makes exceeding the
budget a **defect**, because the engine's response is to silently drop the front
of the prompt, which is the system prompt and with it the assistant's stated
limits. So the two directions of error are not symmetric, and every rule above —
worst-case not mean, an added margin, a hard ceiling at 3.5 — exists to keep the
error on the side that merely drops one old turn too many.

**Rejected alternatives.**

- *Make `Tokenizer` async and use llama.cpp's count directly* — exact, and what
  the earlier comments promised. Rejected on the per-message isolate round-trips
  above. Worth revisiting only if the fitting loop is restructured to tokenize
  each message once and cache by message id, which is possible — messages are
  immutable and carry a UUID — but is a change to #17's fitting function, not to
  the tokenizer.
- *Keep `HeuristicTokenizer` unchanged and simply document that the promise was
  dropped* — honest and free. Rejected because the Hebrew case is a real
  under-count on a model the registry is explicitly designed to accept, and
  because measuring it costs one call at load.
- *Calibrate on a built-in corpus rather than the system prompt* — more
  representative of arbitrary chat. Rejected as speculative: the system prompt is
  the one long text we know for certain the model will be shown, and it is
  already loaded at that point.
- *Fail the model load when calibration fails* — louder. Rejected: the fallback
  is the estimate Phase 2 shipped and is safe by construction, so refusing to
  start a chat over it trades a working conversation for a slightly better
  constant.

**Consequence.** `Prompt.estimatedTokens` stays honestly named — it is still an
estimate, now a model-specific one. `HeuristicTokenizer` is superseded by
`CalibratedTokenizer.uncalibrated()`, which holds the identical formula and
constant, so nothing that depended on the old behaviour changed. The three
comments promising a direct swap in `tokenizer.dart`, `heuristic_tokenizer.dart`
and `prompt.dart` are corrected to point here.

---

## #21 — The design system is the only source of colour, size and spacing

**Status:** Accepted

**Decision.** Every colour, radius, spacing value and text style in the
application comes from `lib/core/theme/app_theme.dart`. Semantic roles that
Material's `ColorScheme` has no vocabulary for — `raised`, `warm`, `done`,
`lineStrong` — live in a `LevColors` `ThemeExtension`, and `ColorScheme` itself
is **derived from those tokens** rather than seeded from a colour. Screens are
built from `lib/core/widgets/lev_widgets.dart`; a screen that writes its own
`Container` with a colour is a defect.

The destructive red (`#9B3B36` light, `#E0928C` dark) is deliberately **not** in
`LevColors`. It sits in a separate `LevDestructive` holder and reaches exactly
one control: the confirm button of "delete all data".

**Rationale.** The palette is what makes the product read as calm, and a seeded
Material scheme cannot express the distinctions this product actually makes —
"a person is involved" is a *role*, not a shade, and it has to mean the same
thing on a status pill, on a support card and nowhere else. Putting the roles in
a `ThemeExtension` is what lets `LevStatusPill` and `LevSupportCard` share one
rule instead of two similar-looking constants.

Keeping the red out of the token set is the same argument inverted. What gives
it force when it appears is that nothing else in the interface is ever this
colour: a cancelled help request goes grey, a model that failed its integrity
check goes amber. A red that is reachable from the palette becomes a red that
gets used.

**Rejected alternatives.**

- *`ColorScheme.fromSeed`, as Phase 0 shipped* — one line, and every Material
  widget themed for free. Rejected: it generates tonal ramps, not roles, so the
  amber that means "a human took this" would have been picked per call site and
  would have drifted within a month.
- *Colours as plain constants in a `LevPalette` class* — simpler than a
  `ThemeExtension`. Rejected: it cannot vary with brightness through
  `Theme.of(context)`, so every widget would need its own light/dark branch, and
  dark mode here is not an inversion — the turquoise lightens to `#6FB3BF` and
  the ink stops at `#E8EAE7` rather than going white.
- *Keeping `#9B3B36` in `LevColors` as `danger`* — tidier. Rejected on the
  reachability argument above.

**Consequence.** `test/core/rtl_lint_test.dart` sweeps `lib/` for
`EdgeInsets.only` / `Alignment.centerLeft` and friends on every run, because
those compile, look right in English, and strand content on the wrong edge in
Hebrew. A line that genuinely needs one says `// rtl-ok`.

---

## #22 — Three sibling destinations, not a navigation stack

**Status:** Accepted — supersedes the nesting half of #9

**Decision.** Routes are flat: `/`, `/chat`, `/chat/:conversationId`, `/aid`,
`/settings`. `LevShell` renders a `NavigationBar` below 900px and a
`NavigationRail` above it, and switching destinations is `context.go`, never
`push`. `ConversationListScreen` is deleted; the conversation list is now
`LevConversationList` inside `Scaffold.drawer` on mobile and a fixed 250px column
on desktop — **one widget**, which decides between the two behaviours by asking
`Scaffold.maybeOf(context)?.hasDrawer`. Settings is the one screen that is
pushed, because it has a back affordance.

**Rationale.** #9 declared Chat and Tasks nested under Home "so each carries a
real back stack". The design has three permanent destinations in a bar, and tabs
are siblings: going Home from a conversation is not "back", and rendering it as
back produces a stack that grows every time someone switches tabs.

What the nesting bought was per-branch navigation state, and here that is
actively unwanted. `chatNotifierProvider` is `autoDispose` precisely because
§5.1 wants a conversation's session — and the KV cache it owns — released when
the conversation is left; preserving a branch's state would hold that memory for
every conversation ever opened, which is the case §8's memory requirement rules
out.

**Rejected alternatives.**

- *`StatefulShellRoute.indexedStack`* — go_router's own answer for exactly this
  shape, and it preserves each branch's stack. Rejected on two counts: the state
  preservation is the thing we do not want (above), and the shell would then own
  the app bar, so every screen would need a channel to publish its own title,
  actions and side list up into it — an inherited widget, or a provider, to
  replace three constructor arguments.
- *Keeping #9's nesting and adding a bar on top of it* — least code changed.
  Rejected: the bar and the stack would then disagree about where "back" goes,
  which is the bug, not the fix.

**Consequence — one capability had to be re-homed.** Deleting a conversation
lived on the list screen that no longer exists, and the design draws no delete
control anywhere. Dropping it was not an option in a privacy product, and putting
a visible destructive button on every row would be wrong in the quietest list
here, so it is a long press (announced by screen readers) or a secondary tap.
**A keyboard-only desktop user cannot currently reach it** — recorded as a real
gap, not an oversight.

---

## #23 — Interface preferences live in the encrypted database, at schema 2

**Status:** Accepted

**Decision.** A `preferences` table — `key TEXT PRIMARY KEY`, `value TEXT` —
holding three keys: `ui.languageCode`, `ui.appearance`, `onboarding.seenAt`.
`schemaVersion` goes to **2** with a real `onUpgrade`. Following the device is
stored as the **absence of the row**, not as a third value.

**Rationale.** CLAUDE.md forbids writing user data to disk outside the encrypted
database. A theme choice is not sensitive, but "sometimes we write outside the
encrypted database" is not a rule anyone can hold, and the exception would be
cited the next time something almost-not-sensitive needed persisting. One store,
one answer. It is also the table the mutual-aid feature's own schema-2 tables
will land beside, so the migration is written once.

Key/value rather than typed columns because these are settings, not entities:
adding one is an insert, and the shape never changes. Absence-as-default because
"follow the device" is the lack of a choice — a sentinel would oblige every
reader to know the sentinel, and the first one to forget would silently pin a
theme.

**Rejected alternatives.**

- *`shared_preferences`* — a plaintext file, one dependency, ten minutes' work.
  Rejected on the rule above.
- *`flutter_secure_storage`, already a dependency* — no new file and no schema
  change. Rejected: that store is for key material, and #12's fail-closed
  contract ("absent is not failure") exists to protect exactly two entries.
  Putting a theme preference beside them makes a read failure there ambiguous.
- *Typed columns for the three settings* — compile-time safety. Rejected: the
  fourth setting would then be a migration across four platforms.

**Consequence — this is the first migration that actually runs.** #14 wrote an
`onUpgrade` that was documentation. `test/core/db/migration_test.dart` seeds a
real schema-1 file from raw DDL and upgrades it. It does **not** use `drift_dev
schema generate`'s helpers: those name each field after its column, and
`messages.text` collides with drift's own `Table.text` builder — the very
collision `Messages.body` with `named('text')` exists to avoid (#14) — so the
generated snapshot does not compile. The DDL in the test is the schema
`drift_schemas/drift_schema_v1.json` describes, column for column.

The migration also re-applies `PRAGMA foreign_keys` in `beforeOpen`, because a
migration opens its own connection and the pragma is per-connection.

---

## #24 — The support message is an asset, and it supersedes the pattern file's copy

**Status:** Accepted — supersedes the presentation half of #18

**Decision.** What the safety layer *shows* moves to
`assets/support/<locale>.json`: a title, a body, a call label, a phone number, a
service name, and a `reviewedOn` date. `SafetyVerdict.matched` remains the
trigger; `supportMessage` in `assets/prompts/safety_patterns_<locale>.json` is no
longer what appears on screen. The card's only action is `tel:`, launched with
`url_launcher`.

**Rationale.** #18 was right that the message must be localised data rather than
a string in Dart, and right that it appears *alongside* the reply. What it could
not anticipate is that the card the design specifies needs four fields and a
dialable number, and a single `supportMessage` string cannot carry a number that
`Uri(scheme: 'tel')` will accept. Splitting them also separates two things with
genuinely different lifetimes: the patterns change when the *language* is tuned,
the number changes when a *service* does.

`reviewedOn` is the point of the file. A number that has gone stale is worse than
a message that never appeared, so the date is in the asset and
`test/core/support/support_resources_test.dart` asserts every shipped locale has
one, that the number is digits only, and — deliberately — that the body promises
neither anonymity nor confidentiality. That varies between services and between
circumstances, and it is not ours to promise on someone else's behalf.

**Rejected alternatives.**

- *Widen `supportMessage` into an object inside the pattern file* — one asset
  instead of two. Rejected: it couples "which phrasings count as distress" to
  "which service answers the phone", and the second is reviewed on a schedule
  the first is not.
- *Let the card fall back silently to nothing when the asset cannot be read* —
  less code. Rejected outright. The chat screen renders the raw
  `state.safetyNotice` on the same amber ground instead; silently dropping this
  particular message is the one outcome not on the table.
- *A link to the service's website beside the number* — more ways to reach help.
  Rejected: this is an application with no network, and a link is a dead button.

**Consequence.** Adding a language now means a pattern file, a support resource,
a corpus entry and an ARB — no code change. The widget itself does not know
`url_launcher` exists: it takes `onCall` and the screen decides, which is what
keeps `lev_widgets.dart` free of platform plugins.

---

## #25 — `url_launcher`, for one URI scheme

**Status:** Accepted

**Decision.** Add `url_launcher`. It is used in exactly one place: opening the
dialler for the support card's number.

**Rationale.** Technical-spec §4 lists the stack and CLAUDE.md forbids
substituting it without approval; this is an addition rather than a substitution,
recorded here so it is a decision rather than a drift. The alternative to a
plugin is a per-platform method channel for `tel:`, which is the same code with
four copies to maintain. It makes no network call and requests no permission —
`ACTION_DIAL` opens the dialler with the number typed in and the person presses
the call button, so nothing here can place a call on its own.

**Rejected alternatives.**

- *A hand-rolled `MethodChannel` per platform* — no dependency. Rejected on
  four-platform maintenance for a two-line feature.
- *Showing the number as selectable text and letting the user dial it* — zero
  dependencies, and honest. Rejected: at the moment this card appears, asking
  someone to copy digits by hand is asking too much.

**Consequence.** `canLaunchUrl` failing is swallowed. A desktop with no dialler
shows the number and does nothing when pressed, which is the correct outcome —
the number is on screen either way, and throwing here would put a crash on the
most fragile screen in the product.

---

## #26 — IBM Plex Sans Hebrew is bundled, never fetched

**Status:** Accepted

**Decision.** Five weights of IBM Plex Sans Hebrew (Light through Bold) ship in
`assets/fonts/` and are declared in `pubspec.yaml`. **`google_fonts` is not
used.** The OFL licence is committed beside them as `assets/fonts/OFL.txt`.

**Rationale.** `google_fonts` downloads its font from the network on first run
and caches it. §8 makes a runtime network call a defect rather than a trade-off,
so the package cannot be used here at all — and its failure mode is quiet, since
it falls back to a system font and merely looks wrong. Bundling costs about
490 KB for all five weights, which is nothing beside the model.

The typography depends on the specific face: body text is set at 1.7 line height
because Hebrew has no ascenders or descenders to break up a line, and dense text
reads as a block. A fallback face would undo the one decision the type scale is
actually making.

**Rejected alternatives.**

- *`google_fonts`* — one line, no assets. Rejected on the offline rule.
- *The system font* — zero bytes. Rejected: the screens would not match the
  design, and the Hebrew system font differs on every target platform, so
  "cross-platform parity" (§8) would fail on the most visible axis there is.
- *Three weights instead of five* — saves roughly 200 KB. Rejected as a false
  economy at this size; Light and Bold exist for states the design has not
  finished specifying, and re-adding a weight later means re-testing every
  screen.

**Consequence.** Downloading the fonts is a **build-time** network fetch, like
the SQLCipher and llama.cpp build hooks (#13, #19). Same conclusion as both: it
does not breach the offline rule, which governs runtime — but the files are
committed, so unlike those hooks this one does not need a mirror in Phase 5.

---

## #27 — The mark is rendered from the design's SVG, by `flutter_svg`

**Status:** Accepted — `LevMark` itself **superseded by #28**, which folds it into `LevLogo`

**Decision.** `lev-mark.svg` and `lev-mark-micro.svg` are copied verbatim from
the design's `lev-logo/svg/` into `assets/branding/`, and `LevMark` renders them
with `flutter_svg`, tinted by a `ColorFilter` in `srcIn`. Below 24 logical pixels
it switches to the `micro` file. **`Icons.favorite_border` is not used anywhere**,
and a test under `test/core/widgets/lev_mark_test.dart` fails the build if it
comes back.

**Rationale.**

*On not using Material's heart.* The logo is an **open** heart — two separate
strokes that stop short of meeting, at the top of the cleft and again at the
point. `Icons.favorite_border` is a single closed outline. It is near enough to
pass a glance and wrong enough to notice beside the launcher icon, which is
exactly how it survived the first pass of the design work.

*On the SVG being the source of truth.* This started as a `CustomPainter` with
the SVG's four cubic segments transcribed into Dart. It rendered identically and
cost no dependency, and it was still the wrong shape of solution: it duplicates
the designer's geometry into code, so redrawing the logo means someone
re-transcribing two `d` attributes correctly and noticing that they have to.
Nothing would fail if they did not. With the asset, replacing the logo is
replacing a file.

*On not using the pack's PNGs.* A tinted PNG is a real option —
`BlendMode.srcIn` over a silhouette does work, so the "a PNG cannot be recoloured"
claim made while writing the painter was wrong. Two things decide against it
anyway. The mark is drawn at 21, 28, 30, 34 and 44 logical pixels, and a 512-pixel
raster scaled to 21 is visibly softer than a vector at the size the wordmark
actually uses. And the pack ships **two geometries**, not one image at two sizes:
the `micro` file carries a heavier stroke because at 20 pixels the regular 3.4
stroke thins out until the mark reads as a smudge. That is a design decision the
PNGs cannot express.

*On the dependency.* `flutter_svg` is pure Dart with no platform channel and no
native build step, and it reads a bundled asset — no network, so §8 is untouched.
It is an addition to the stack rather than a substitution, recorded here for the
same reason `url_launcher` is (#25).

**Rejected alternatives.**

- *A `CustomPainter` with the paths transcribed* — no dependency, vector-sharp,
  freely colourable. It was built and then replaced, on the duplication argument
  above. Worth reaching for again only if `flutter_svg` becomes unmaintained.
- *`Image.asset` with a `color` filter over `mark-turquoise-512.png`* — the
  simplest option and no dependency at all. Rejected on the raster softness at
  21 pixels and on the missing `micro` geometry.
- *Shipping the pack's pre-coloured PNGs as they are* — no filter needed.
  Rejected outright: the mark appears in four colours (turquoise light, turquoise
  dark, white, amber) and the pack has two.
- *Pre-compiling the SVGs to `.vec` with `vector_graphics_compiler`* — faster
  first paint. Rejected as premature for two files of about 550 bytes, and it
  would reintroduce a generated artifact between the design's file and the app.

**Consequence — the test suite got slower.** `SvgPicture.asset` does real
asynchronous asset loading, and every widget test that pumps a screen now waits
for it: the suite went from roughly 27 seconds to roughly 77. Accepted, but it is
the one thing the painter was better at.

---

## #28 — One logo widget, three lockups, and a font that draws three letters

**Status:** Accepted — completes #27, which covered only the symbol

**Decision.** The logo is `LevLogo`, with three variants whose every measurement
derives from a single `height`:

| variant      | what it is          | where it is allowed                       |
|--------------|---------------------|-------------------------------------------|
| `mark`       | the symbol alone    | the bars and the side rail                |
| `vertical`   | symbol above word   | the first-run screen and the splash       |
| `horizontal` | symbol beside word  | outside the application only              |

**In the application's bars the wordmark does not appear** — only the symbol.
The word is set in `OutfitSemiBold`, subset to A–Z at one weight (3.3 KB), which
is used for this and for nothing else. `LevMark` and `LevWordmark` are deleted.

**Rationale.**

*On the bars carrying no word.* This is the design's rule and it is the right
one: a name printed on every screen stops being read within a day, and the bar's
job is to say where you are, which "LEV" never does. The first pass of this work
put a hand-assembled `LevMark` + `Text('LEV')` lockup in the home bar — wrong in
both halves, and wrong in the direction that is hardest to notice, because it
looks deliberate.

*On the word having a font of its own.* The wordmark is part of the logo, not
copy, and setting it in the interface face makes it a heading that happens to say
the product's name. The subset is what makes this cheap rather than indulgent:
three letters, one weight, 3.3 KB — less than 1% of what the five interface
weights cost. It is also self-policing, since any other text set in it would
render as blanks.

*On no image file of the lockup.* Composing it from the symbol and the font means
it is sharp at any size, recolours with the theme, and — the part that matters —
cannot drift out of step with either half. A PNG of the lockup would be a third
artifact to keep in sync with the two that already define it.

*On the ratios being fixed in the widget.* `vertical` sets the word at half the
mark and `horizontal` at 0.85 of it. Leaving those to call sites is how a logo
ends up with six slightly different proportions across one application.

**Rejected alternatives.**

- *Keep the mark-plus-word lockup in the bar* — it is a brand surface and it did
  look deliberate. Rejected on the design's explicit rule, and on the reading
  above.
- *Ship the wordmark as an SVG path like the symbol* — one fewer font, and no
  font loading at all. Rejected: the letterforms would then be frozen at whatever
  outline was exported, and the word could no longer follow text scaling or be
  read by anything but the eye. The font is also smaller than the outlines.
- *The full Outfit family instead of a subset* — one less build step for whoever
  updates it. Rejected at roughly 50× the size for characters nothing renders.
- *Route `'LEV'` through the ARB files like every other string* — consistent with
  #11. Rejected: it is a brand name, identical in every locale, and a logo that
  cannot draw itself without `AppLocalizations` has a dependency it has no
  business having. It stays a literal inside `lev_logo.dart` and nowhere else,
  which a static test enforces.

**Consequence — four static guards, and one deliberate omission.**

`test/core/widgets/lev_logo_test.dart` fails the build on `Icons.favorite`, on
`Text('LEV')`, on any reach into `assets/branding/`, and on any use of
`OutfitSemiBold` outside `lev_logo.dart`. Each of those is a way the logo has
already gone wrong once or could plausibly go wrong again.

The omission is the safety layer's support card, which **lost its icon
entirely**. The design draws a Material heart there, and that is not available:
the logo is never painted amber, and a Material heart beside the logo's heart
puts two heart shapes in one application. Any other glyph would compete with what
the card is saying. The card is distinct enough without one — an amber ground, a
bolder title, a filled call button — and without it, it reads as a person
reaching out rather than as a system alert, which is what it has to be.

---

## #29 — The design package's screenshots are reference material, not an asset

**Status:** Accepted

**Decision.** `docs/design/` — the design system's README and all twenty screen
captures — is committed and is the reference to consult before building a screen,
as CLAUDE.md's design chapter now requires. It is **not** declared under
`flutter: assets:` in `pubspec.yaml`, though the package's own instructions ask
for that. `tool/check_design.sh` is committed and runs after every UI change.

**Rationale.** Declaring `docs/design/screens/` as a Flutter asset would put about
a megabyte of PNGs inside every APK and every desktop bundle, for images no line
of code loads. §8 makes install size a budget, and this is a build artifact for
developers, not product data.

**Rejected alternatives.**

- *Follow the instruction and declare them* — the package asked. Rejected on the
  size argument; the instruction was written for a project without an install-size
  constraint in its spec.
- *Keep the screenshots outside the repository* — no weight at all. Rejected: the
  rule "look at the screen's image before building it" is worthless if the images
  live in someone's Downloads folder, and reviewing a UI change against them is
  exactly when they need to be at a stable path.

**Consequence — two of the twenty are known to be wrong.**
`04-home-desktop.png` and `07-chat-desktop.png` show the navigation rail on the
**left** in Hebrew. That is a rendering artifact of the mockup, not a design
decision: the rail belongs on the start side, which is the right in Hebrew, and
`LevShell` already builds it that way — the rail is the first child of the `Row`,
so RTL places it correctly with no branch. **Read nothing about column order from
those two files.** A corrected package is expected; when it lands, they and
`lev_shell.dart` should be re-checked together.

---

## #30 — A conversation row answers the pointer, and carries its own menu

**Status:** Accepted — supersedes the affordance half of #22, and the "no rename
action" half of `ChatRepository.updateTitle`

**Decision.** A row in the conversation list changes ground under the pointer
and under keyboard focus, using a new `LevColors.hover` role. Its actions —
**rename** and **delete** — sit behind one menu (`showLevMenu`), and **how that
menu is reached is the platform's own idiom**:

| platform | how the menu opens |
|---|---|
| phone / tablet | a long press, and nothing on the row |
| pointer | a `⋯` the row shows under the pointer or on keyboard focus, a right-click, or a long press |

Where the control exists its space is held whether or not it is showing, so the
title does not reflow under the pointer.

**Rationale.**

*On the hover state.* The list is a column of a dozen near-identical titles —
several of them literally the placeholder — and until a row was selected nothing
under the cursor said which one a click would open. This is the one question a
list has to answer before the click, and `primarySoft` cannot answer it: hover
and selected are different facts, and a row can be either, both, or neither. So
`hover` is a neutral step away from `surface`, not a wash of the turquoise, and
selected still wins where they collide.

*On the actions being behind a menu rather than on the row.* A visible delete on
every row would put a destructive action twelve times over in the quietest list
in the product. A menu costs one click and buys a list that is not a minefield.

*On the phone carrying nothing at all.* The first build showed the `⋯` always on
touch, on the reasoning that a control no hover can reveal has to be shown to
exist. On the emulator that came out as a stripe of twelve dots down the drawer,
pulling the eye harder than the twelve titles beside them — the same noise the
menu was introduced to avoid, reintroduced one platform over. Every other
conversation list on a phone answers this with a long press, and a person
arriving from any of them already knows the gesture. So the affordance is not
missing on touch; it is the platform's, rather than one drawn on top of it.

*On adding a rename at all.* Product-spec §5 lists no rename action, and the
title has until now been derived from the opening message. But a derived title
is a guess — "…I feel really bad, these" is a sentence, not a name — and the
list is the only way back into a conversation. Renaming does not fight the
derivation: the derived title is written only where there is none, so a name a
person chose is never overwritten.

*On the rename not being confirmed while the delete is.* Renaming is reversible
by renaming again. Asking "are you sure?" in front of something undoable is
exactly how a confirmation stops being read by the time it guards a deletion.

*On `hover` being a new colour role.* The design package's palette did not ship
one, and this is the first added role. It is a role and not a value — light
steps down towards `canvas`, dark steps up past `raised`, because on a dark
ground the eye reads lighter as nearer — so the widget carries no brightness
branch. **The two values are ours, not the package's, and should be confirmed
against it.**

**Rejected alternatives.**

- *Rely on `InkWell`'s built-in hover overlay* — no new token, no state to hold.
  Rejected twice over: the tile's own opaque background paints over the ink, and
  Material's default overlay is a low-opacity black rather than a LEV colour.
- *Keep long-press as the only way to delete (#22)* — it was already built.
  Rejected: it is invisible, it is the wrong gesture on a desktop, and it left
  the keyboard with no route at all, which #22 recorded honestly as a gap.
- *A visible trailing delete on each row* — one click instead of two. Rejected
  on the reading above.
- *Let the button appear and disappear from the layout* — no reserved space, no
  `Visibility`. Rejected: the title would shorten and re-ellipsise the moment
  the pointer crossed the row, which reads as the list twitching.
- *Show the button on every platform always* — one rule instead of two.
  Rejected on the phone reading above; it was built that way first and looked
  wrong on the first emulator run.
- *Keep the button on touch but make it quieter* — grey it down, tuck it beside
  the title. Rejected: twelve of anything in a column is a column, however
  quiet, and it would still not be what a phone user reaches for.

**Consequence.** `LevColors` gains a field, so every future palette must define
it. `showLevMenu` is now the product's only menu surface; the mutual-aid rows
(Phase 4) should use it rather than growing one of their own. The delete flow is
one step longer than it was — the menu, then the confirmation — which is what
the two tests covering it now assert.

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

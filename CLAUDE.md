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
0. Project scaffold
1. Storage + security foundation (encrypted DB, key management)
2. Chat, prompt layer & context management — end-to-end against a **fake** engine, no native code
3. Real LLM engine (llama.cpp, model registry, streaming) — swapped in behind the Phase 2 contracts
4. Mutual-aid feature (local-only, with transport stub)
5. Packaging + offline distribution (APK, Windows, macOS, Linux)

**Note the order of 2 and 3: spec v0.2 inverted them.** The chat is built and
finished first, against `FakeLlmService`, because the native binding is the
riskiest and most environment-dependent part of the build — and because
everything the chat actually *is* (history, context assembly, the system prompt,
safety) is pure Dart that needs no model to be correct. Phase 3.1 replaces one
binding in `lib/core/di/llm_providers.dart`; if it needs to touch anything under
`features/chat`, the abstraction has failed.

Later releases (only when asked): iOS support, real P2P BLE-mesh transport, Hebrew model.

## Data model rule
Every shareable entity uses a **UUID** primary key (never auto-increment), carries `createdAt`/`updatedAt` + `originDeviceId`, and uses tombstones (`isDeleted`) instead of hard deletes — so future P2P sync can merge without conflicts. See technical spec Section 6.

## Decisions log
The rationale for every technical decision (and rejected alternatives) is recorded in `docs/technical-decisions.md`. When making a significant new technical decision, append it there with its reasoning.

## Design — binding rules

The full design system: `docs/design/README.md`. Screenshots of every screen:
`docs/design/screens/`. **Before building a screen, look at that screen's image in
that folder.** They are the source of truth, not this file and not the mockup PDFs.

1. **No colour in a screen's code.** Every colour comes from
   `Theme.of(context).extension<LevColors>()!` (or `levColors(context)`). A
   `Color(0x…)` outside `lib/core/theme/app_theme.dart` is a bug.
2. **No spacing numbers.** Only `LevSpace` (4·8·12·16·24·32·48·64) and `LevRadius`.
3. **No improvised widget.** Button = `LevButton`. Card = `LevCard`. Bubble =
   `LevBubble`. Empty or error state = `LevEmptyState`. Status pill =
   `LevStatusPill`. Logo = `LevLogo`. A missing component is added to
   `lib/core/widgets/lev_widgets.dart`, never improvised in the screen.
4. **The logo only through `LevLogo`.** Never `Text('LEV')`, never a hand-placed
   `Icon`.
   - `LevLogo.mark` in the bars and the side rail — **without the word LEV**.
   - `LevLogo.vertical` on the first-run screen and the splash.
   - `LevLogo.horizontal` only outside the application.
   - The `OutfitSemiBold` font is for the logo's wordmark **and nothing else**;
     everything else is IBM Plex Sans Hebrew.
5. **RTL:** `EdgeInsetsDirectional`, never `EdgeInsets` with `left`/`right`.
   `AlignmentDirectional`, never `Alignment.centerLeft` / `centerRight`.
6. **No `google_fonts`.** Fonts are bundled in `assets/fonts`. A network read is a bug.
7. **No red** except the confirm button of "delete all data".
8. **48dp minimum touch height** for anything tappable.
9. **Every chat error screen ends** with the sentence saying mutual aid still works.
10. **The safety layer's message** (`LevSupportCard`) appears *beside* the model's
    reply, never in its place, and never as a modal dialog. Its only action is
    `tel:`, never a link.

### After any UI change

```
bash tool/check_design.sh
flutter analyze
```

Both must pass. If `check_design.sh` fails — fix it, do not work around it.

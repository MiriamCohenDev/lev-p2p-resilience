# `core/di` — cross-feature wiring

Riverpod providers that bind a **domain interface** to its **data implementation** live here.

The rule (CLAUDE.md, technical-spec §3.4): a feature never imports another feature's
`presentation` or `data`. When one feature needs something another owns, it depends on the
abstract interface in `domain` and gets the implementation from a provider registered here.

Providers that belong to exactly one feature stay inside that feature; only cross-cutting
bindings belong in this folder.

Empty in Phase 0 — there are no interfaces to bind yet. Expected occupants:

| Phase | Binding |
|---|---|
| 1 | `AppDatabase`, `KeyManager`, repository implementations |
| 2 | `LlmService` → llama.cpp binding, `ModelSelector` |
| 4 | `TransportService` → no-op stub |

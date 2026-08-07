# rr-up-down-load

Part of the **RailsRuntimes** ecosystem. Apache-2.0.

Portable **SHACL-constrained JSON-LD** export/import — *store your data on your laptop*.

| Piece | Role |
| --- | --- |
| RR Bundle Profile v1 | One self-contained `.rr.jsonld` (JSON-LD 1.1, inline `@context`, no blank nodes) |
| SHACL generator | Deterministic Core shapes from `rr-model` schemas |
| Canonical JSON | RFC 8785-style key order; omit nulls; byte-stable re-export |
| Reader | Iterate entities without app code |
| Validator | Focused RR-profile checks (no heavy RDF dependency) |
| Store adapters | Export/import via `rr-store` (server AR + browser OPFS bindings) |

Ruby namespace: `RailsRuntimes::UpDownLoad` (`require "rails_runtimes/up_down_load"`).

```ruby
runtime = RailsRuntimes::UpDownLoad::Runtime.new
runtime.register(schema, surface: :server, repository: server_repo)
runtime.register(schema, surface: :browser, repository: browser_repo)

bytes = RailsRuntimes::UpDownLoad.download(
  runtime: runtime,
  created_at: "2026-08-06T12:00:00.000000Z",
  application: "notes-demo"
).value

RailsRuntimes::UpDownLoad.upload(bytes, runtime: runtime) # after clear
```

**Pairs with:** `rr-model`, `rr-store`, `rr-store-opfs`.

## Status

`0.1.0` — Bundle Profile v1 core + round-trip gate.

## Rust reader (contract only)

A standalone Rust reader/validator is **not** shipped in this gem. Any independent implementation MUST accept RR Bundle Profile v1 JSON-LD, enforce no blank nodes / no remote `@context`, validate embedded SHACL Core shapes (or equivalent), and treat `rr:entityToken` as the portable identity. See architecture guidance §11 for the full contract. No Rust code lives in this repository yet.

## Deferred

Sync, encryption, signatures, merge import modes.

## Copyright

(c) 2026 CBI BUSINESS TRANSACTIONS, LLC. Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine. Licensed under Apache-2.0.

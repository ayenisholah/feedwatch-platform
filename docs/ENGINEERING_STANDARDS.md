# Engineering standards

These apply in every Feedwatch repo. Where a tool enforces a rule, it's named.

## Modularity

- One responsibility per module. Functions stay short: under 60 lines, and simple enough to test directly (clippy `too_many_lines`, ESLint `max-lines-per-function`).
- Pure logic lives apart from I/O. In the poller, `manifest`, `abi` and `checks` do no I/O; time, configuration and data are passed in.
- Entrypoints (`main.rs`, Next.js pages) only wire things together.
- Repos never import each other's code. They share data only through the [data contract](DATA_CONTRACT.md).

## Dependency injection

Pass collaborators in. In Rust, that means a trait such as `RpcTransport`, `Clock` or `InfluxWriter`, with a small fake in tests. In TypeScript, it means a function argument. Tests use fakes, not module mocks.

## Validation and errors

- Validate at every boundary: environment, RPC responses, manifests, HTTP inputs, API responses in the client (serde with `deny_unknown_fields` where it helps; Zod in the client).
- Parse once, then use the typed result.
- In Rust, expected failures are `Result` values with `thiserror` types, and `anyhow` only in `main`. No `unwrap` or `expect` outside tests (clippy `unwrap_used`, `expect_used`).
- Errors returned to API clients never expose internals.

## Data

- Timestamps are UTC. Prices keep the raw integer answer alongside the scaled float.
- No secrets in code, images or logs. Secrets come from `.env` locally and from SSM Parameter Store on AWS (gitleaks).

## Logging

Structured JSON through `tracing` with `tracing-subscriber`'s JSON formatter. One line per poll cycle with its duration and failures. CloudWatch metrics use embedded metric format lines.

## Naming

Rust follows the Rust API guidelines. In TypeScript, files are kebab-case, components and types are `PascalCase`, functions are `camelCase`, factory functions start with `create`, and validators start with `parse`.

## Comments and history

- Comments explain why, never what. No commented-out code, and no TODOs without an issue.
- Conventional Commits (commitlint). One complete change per commit, with its tests.
- **No tool attribution in commits or pull requests.** commitlint rejects `Co-Authored-By` and "generated with" lines.
- `main` changes only through pull requests (pre-push hook).

## Definition of done

- The change traces to a requirement ID in [requirements](REQUIREMENTS.md), and its test is named `[ID] behaviour`.
- The repo's check passes: `./scripts/check.sh` in Rust repos, `npm run check` in the web repo, the same commands CI runs.
- Every external claim it relies on is in [verified facts](VERIFIED_FACTS.md).
- `docs/PROGRESS.md` in that repo is updated in the same commit.

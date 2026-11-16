# Test strategy

## What each thing needs

| Thing                                              | Tests                                                                                                                                                             | Where                                              |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| Pure function (manifest merge, ABI decode, checks) | Unit tests, including edge cases and malformed input                                                                                                              | `#[cfg(test)]` in the module                       |
| I/O adapter (RPC, Influx writer, Coinbase)         | Integration tests against a fake HTTP server (`wiremock`)                                                                                                         | `tests/`                                           |
| Store behaviour (writes, Flux queries)             | Integration tests against real InfluxDB 2 in Docker (`testcontainers`)                                                                                            | `tests/`, marked `#[ignore]` locally and run in CI |
| API route                                          | Request tests through `tower::ServiceExt::oneshot` with a fake store, plus one InfluxDB integration test per route                                                | api `tests/`                                       |
| UI component                                       | Vitest and Testing Library, with an axe check                                                                                                                     | web `test/`                                        |
| Page                                               | Playwright against a stub API, in light and dark themes, by keyboard, with axe                                                                                    | web `e2e/`                                         |
| Contract                                           | API: the OpenAPI document matches the committed snapshot. Web: generated types match the pinned `openapi.json`. Poller: written points match `influx-schema.json` | each repo                                          |

## Naming

Tests that prove a requirement start with its ID: `fr_fw_3_stale_past_heartbeat_grace` in Rust, `[FR-FW-7] shows the empty state` in TypeScript.

## Coverage

- Rust: `cargo llvm-cov --fail-under-lines 95` in CI.
- Web: Vitest coverage at 100% per file for `src/lib` and `src/components`.

Close coverage gaps with real behaviour tests. Don't add exclusions.

## Live checks

Anything that depends on a live public endpoint is checked by hand or by a manually triggered workflow, never in the default CI run. Record results in [verified facts](VERIFIED_FACTS.md).

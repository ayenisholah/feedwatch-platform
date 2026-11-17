# Progress (system)

**Updated:** 2026-11-17

Read this first. It covers the whole system; each repo has its own `docs/PROGRESS.md` for detail.

## Current milestone

**M0 scaffold: done.** **M1 poller: next.**

## Next step

M1, following [the M1 plan](plans/m1-poller.md). First `chore/dependabot-triage` across the repos, then `feat/manifest` in `feedwatch-poller` (FR-FW-1). Four Ethereum feeds use `cron` schedules instead of a heartbeat; the plan covers them.

## Done

| Date       | Work                                                                                                                                                                                                                                                                                                        |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-16 | M0: four repos scaffolded with docs, quality gates and CI; manifests vendored at RedStone monorepo commit `c75bac13`; live endpoint facts recorded (F-1 to F-12). Local InfluxDB and Grafana checked: the datasource connects.                                                                              |
| 2026-11-17 | Repos published (public) under `ayenisholah`; CI green on `main` in all four. Fixes: web lockfile generated under Node 24 (web #7); Dependabot uses `docker-compose` here (#3). AWS read-only preflight through the MCP: only eu-north-1 is allowed (F-13, [deployment](DEPLOYMENT.md#account-and-region)). |

## In progress

Nothing.

## Blocked or waiting on the owner

- **AWS (M4):** owner's OK before each create step; Namecheap DNS records for the ACM validation and `feedwatch.sholaayeni.xyz`. Region is fixed at eu-north-1 by the account's policy.

## Open housekeeping

- Dependabot pull requests are open in every repo (actions bumps; web: TypeScript 7, ESLint 10, jsdom 31, @types/node 26; Rust repos: the rust 1.100 image). Triage them at the start of M1:
  - Merge the GitHub Actions bumps if CI passes.
  - Keep `@types/node` on 24, matching `.nvmrc`. Close that PR and add an ignore rule.
  - Take TypeScript 7 and ESLint 10 only if `eslint-config-next` supports them.
  - Bump the Rust image together with `rust-toolchain.toml`, never alone.

## Decisions log

- 2026-11-16: multi-repo (ADR 0001); Rust server, TypeScript client (ADR 0002); InfluxDB only (ADR 0003); vendored manifests (ADR 0004); no Terraform, AWS through the MCP (ADR 0005); one EC2 host with S3 and CloudFront (ADR 0006).

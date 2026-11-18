# Progress (system)

**Updated:** 2026-11-18

Read this first. It covers the whole system; each repo has its own `docs/PROGRESS.md` for detail.

## Current milestone

**M0: done. M1: code done; close-out pending. M2: in progress. M4: live, with deploy on every merge.**

## Next step

1. **Owner:** add the Namecheap A record `feedwatch` → `16.192.242.39`. Then set `/feedwatch/site/address` and `/feedwatch/site/url` to the domain and deploy (DEPLOYMENT, "Custom domain and HTTPS").
2. Close M1: record the soak findings, mark FR-FW-2 to 5, FR-FW-8 and NFR-1 done, and set the roadmap.
3. M2 in feedwatch-api: `feat/feeds-routes`, then `feat/compare`, `feat/incidents`, `feat/openapi` and `feat/limits`.

## Done

| Date       | Work                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-18 | NFR-3 done: the deployer key is in all four repos. Merging platform #18 and the poller, API and web `Deploy` callers (#13, #7, #10) started four automatic deploys. All four ran through `feedwatch-deploy`, one at a time, and passed the smoke check. Both alarms are back to `OK`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| 2026-11-18 | Outage found and fixed: from 11:56 on 2026-11-17, every poll failed (146/146) for about 11 h, because the FR-FW-9 test had left the dead URL `http://127.0.0.1:9` in the host's `.env`. The `PollCycleFailed` alarm fired as designed (FR-FW-9 done). A redeploy rewrote `.env` from SSM; polling is back at about 280 ms per cycle. The API from `feat/influx-client` (api #6) is live, with its CORS origin from `/feedwatch/site/url` (#17). The first redeploy ran the old `deploy.sh`, because bash runs the copy it opened before `git pull`; the `feedwatch-deploy` SSM document now pulls first. CD: SSM document `feedwatch-deploy`, IAM user `feedwatch-deployer` (scoped, checked with the policy simulator) and the `Deploy` workflow (ADR 0008). |
| 2026-11-16 | M0: four repos scaffolded with docs, quality gates and CI; manifests vendored at RedStone monorepo commit `c75bac13`; live endpoint facts recorded (F-1 to F-12). Local InfluxDB and Grafana checked: the datasource connects.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| 2026-11-17 | Repos published (public) under `ayenisholah`; CI green on `main` in all four. Fixes: web lockfile generated under Node 24 (web #7); Dependabot uses `docker-compose` here (#3). AWS read-only preflight through the MCP: only eu-north-1 is allowed (F-13, [deployment](DEPLOYMENT.md#account-and-region)).                                                                                                                                                                                                                                                                                                                                                                                                                                                   |

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
- 2026-11-18: every merge to `main` deploys through GitHub Actions, as a scoped IAM user, because the SCP blocks OIDC; the owner controls the organisation (ADR 0008).

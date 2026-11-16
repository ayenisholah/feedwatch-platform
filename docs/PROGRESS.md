# Progress (system)

**Updated:** 2026-11-16

Read this first. It covers the whole system; each repo has its own `docs/PROGRESS.md` for detail.

## Current milestone

**M0 scaffold: done.** **M1 poller: next.**

## Next step

In `feedwatch-poller`, branch `feat/manifest` (FR-FW-1): merge each feed's `updateTriggersOverrides` into its manifest's defaults, and return `Vec<Feed>` with the chain, feed ID, address, heartbeat and deviation threshold. Start from the existing test `fr_fw_1_manifests_parse` in `src/manifest.rs`.

## Done

| Date       | Work                                                                                                                                                              |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-11-16 | M0: four repos scaffolded with docs, quality gates and CI; manifests vendored at RedStone monorepo commit `c75bac13`; live endpoint facts recorded (F-1 to F-11). |

## In progress

Nothing.

## Blocked or waiting on the owner

- **GitHub repos:** created as private if the owner approved on 2026-11-16; otherwise run the commands in the root `README.md`. Make them public when M3 is done.
- **AWS (M4):** owner's OK before each create step; Namecheap DNS records for the ACM validation and `feedwatch.sholaayeni.xyz`.

## Decisions log

- 2026-11-16: multi-repo (ADR 0001); Rust server, TypeScript client (ADR 0002); InfluxDB only (ADR 0003); vendored manifests (ADR 0004); no Terraform, AWS through the MCP (ADR 0005); one EC2 host with S3 and CloudFront (ADR 0006).

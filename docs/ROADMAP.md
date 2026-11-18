# Roadmap

**Updated:** 2026-11-18

Each step is one branch and one pull request in the named repo. [Progress](PROGRESS.md) shows where things stand.

| Milestone | Outcome                                                                | Status                                                                                                               |
| --------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| M0        | Scaffold: four repos, docs, quality gates, CI                          | Done                                                                                                                 |
| M1        | Poller writes real feed data and checks to InfluxDB; Grafana dashboard | Done                                                                                                                 |
| M2        | Rust API serves feeds, compare and incidents                           | Done                                                                                                                 |
| M3        | Web client in Frox                                                     | Done                                                                                                                 |
| M4        | Deployed on AWS through the AWS MCP                                    | Live at https://feedwatch.sholaayeni.xyz; every merge to `main` deploys (ADR 0008); CloudFront and CodeBuild pending |

## M1: poller (`feedwatch-poller`)

The detailed plan, with the order, tests and verification for each branch, is in [plans/m1-poller.md](plans/m1-poller.md). Start with `chore/dependabot-triage`.

| Branch                            | Delivers         | Notes                                                                                                                               |
| --------------------------------- | ---------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `feat/manifest`                   | FR-FW-1          | Merge per-feed overrides into the defaults; normalise feed IDs; keep chain ID and adapter address                                   |
| `feat/abi`                        | part of FR-FW-2  | Encode `latestRoundData()` `0xfeaf968c` and `decimals()` `0x313ce567`; decode the 5-word answer; reject short or odd-length results |
| `feat/rpc`                        | FR-FW-2, NFR-1   | Batches of 20 or fewer `eth_call`s, timeout, retry with backoff, failover to the second provider; fake RPC tests                    |
| `feat/checks`                     | FR-FW-3, FR-FW-4 | Pure functions; time passed in                                                                                                      |
| `feat/reference`                  | FR-FW-4          | Chainlink ETH/USD and BTC/USD on mainnet, Coinbase spot; 30 s cache                                                                 |
| `feat/influx-sink`                | FR-FW-5          | Line protocol per [data contract](DATA_CONTRACT.md); incident open and close                                                        |
| `feat/poll-loop`                  | NFR-1, NFR-2     | 60 s loop, `/health`, `/metrics`, EMF `PollCycleFailed` log line                                                                    |
| platform `feat/grafana-dashboard` | FR-FW-8          | Dashboard JSON in `grafana/dashboards/`                                                                                             |

## M2: API (`feedwatch-api`)

`feat/influx-client`, then `feat/feeds-routes`, `feat/compare`, `feat/incidents`, `feat/openapi` and `feat/limits` (GR-2).

## M3: web (`feedwatch-web`)

`feat/api-client` (types from the pinned `openapi.json`, Zod), then `feat/overview`, `feat/feed-detail`, `feat/compare-page` and `feat/incidents-page`.

## M4: AWS (`feedwatch-platform`)

Follow [deployment](DEPLOYMENT.md) step by step through the AWS MCP, then prove FR-FW-9.

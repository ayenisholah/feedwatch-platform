# Feedwatch specification

**Status:** Draft v1 · **Updated:** 2026-11-16

Feedwatch monitors RedStone push price feeds from the outside. It reads the same public on-chain values a lending protocol reads, and checks them against the update rules RedStone publishes for each feed. [Requirements](docs/REQUIREMENTS.md) define what must be true and how it's checked. The [roadmap](docs/ROADMAP.md) shows what's built.

## Use cases

| Job                                       | Who                                  | How Feedwatch does it                                                                              |
| ----------------------------------------- | ------------------------------------ | -------------------------------------------------------------------------------------------------- |
| Know a feed is fresh before relying on it | Protocol engineer integrating a feed | Compare each feed's last update with its configured heartbeat                                      |
| Spot a missed price update                | Risk or oracle engineer              | Flag a feed that hasn't updated after a reference price moved further than its deviation threshold |
| Compare one asset across chains           | Multi-chain protocol team            | Show the 7 feeds on Ethereum, Arbitrum and Base side by side, with the spread                      |
| See history and incidents                 | Anyone                               | Grafana dashboards and an incident list, from the same time series                                 |

## What it reads

- **Feed list and rules.** RedStone's relayer manifests from [`redstone-oracles-monorepo`](https://github.com/redstone-finance/redstone-oracles-monorepo), path `packages/relayer-remote-config/fallback/relayer-manifests-multi-feed/`. Files: `ethereumMultiFeed.json`, `arbitrumOneMultiFeed.json` and `baseMultiFeed.json`. Each feed has a `priceFeedAddress` and optional `updateTriggersOverrides`. Each file has default `updateTriggers` (0.5% deviation, 24h heartbeat on 2026-11-16). The manifests are vendored in `feedwatch-poller/manifests/`, with the source commit recorded.
- **Feed values.** `latestRoundData()` and `decimals()` on each feed address, through public JSON-RPC endpoints, with two providers per chain.
- **Reference prices** for ETH, BTC and USDC: Chainlink feeds on Ethereum mainnet, and the Coinbase public spot price.

No API key is needed. RedStone's off-chain gateways need one, so they're out of scope (see [verified facts](docs/VERIFIED_FACTS.md)).

## Checks

| Check              | Rule                                                                                  | Status                 |
| ------------------ | ------------------------------------------------------------------------------------- | ---------------------- |
| Freshness          | `now - updatedAt > heartbeat × 1.1`                                                   | `stale`                |
| Missed update      | `abs(reference - value) / value > deviationThreshold`, and `now - updatedAt > 10 min` | `drift`                |
| Read failure       | Every provider for the chain failed this cycle                                        | `error`                |
| Otherwise          |                                                                                       | `ok`                   |
| Cross-chain spread | `(max - min) / median` across chains, for feeds present on all three                  | reported, not a status |

An incident opens when a feed leaves `ok` and closes when it returns.

## Architecture

```
public RPCs, Chainlink, Coinbase ◀── poller (Rust) ──▶ InfluxDB ──▶ Grafana
                                                         ▲
                                              api (Rust, Axum)
                                                         ▲  same origin, /api/*
                                    web (Next.js static export, TypeScript)
```

- Rust runs every server and worker; TypeScript is only in the browser ([ADR 0002](docs/adr/0002-rust-server-typescript-client.md)).
- InfluxDB is the only store ([ADR 0003](docs/adr/0003-influxdb-only-store.md)), following the [data contract](docs/DATA_CONTRACT.md).
- It runs on AWS: one EC2 host with Docker Compose, the client on S3 behind CloudFront, logs and alarms in CloudWatch ([ADR 0006](docs/adr/0006-single-ec2-host.md), [deployment](docs/DEPLOYMENT.md)).

## Non-goals

- Verifying signed off-chain data packages (needs a RedStone API key).
- Running blockchain nodes.
- Paging or alert delivery beyond a CloudWatch alarm email.
- High availability. One host is enough for a public monitor of public data.

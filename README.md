# feedwatch-platform

[![CI](https://github.com/ayenisholah/feedwatch-platform/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ayenisholah/feedwatch-platform/actions/workflows/ci.yml) [![Licence: MIT](https://img.shields.io/badge/licence-MIT-blue)](LICENSE) [![Rust](https://img.shields.io/badge/server-Rust-orange)](https://github.com/ayenisholah/feedwatch-poller)

The hub of [Feedwatch](SPEC.md), a monitor for RedStone's on-chain push price feeds. This repo holds the system docs, the data contract shared by the other repos, the local Compose stack, Grafana provisioning and the AWS deployment notes.

> **Status: M1 (poller) nearly done.** The poller checks all 146 RedStone push feeds on Ethereum, Arbitrum and Base every minute, writes to InfluxDB, and the Grafana dashboard is provisioned. The API (M2), web client (M3) and AWS deployment (M4) are next. See [progress](docs/PROGRESS.md) and the [roadmap](docs/ROADMAP.md).

## Repos

| Repo                                                                  | Language                           | Role                                                                                                                          |
| --------------------------------------------------------------------- | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `feedwatch-platform` (this one)                                       | Docs, YAML                         | Specification, requirements, ADRs, [data contract](docs/DATA_CONTRACT.md), Compose, Grafana, [deployment](docs/DEPLOYMENT.md) |
| [`feedwatch-poller`](https://github.com/ayenisholah/feedwatch-poller) | Rust                               | Reads every feed over public RPCs, runs the checks, writes to InfluxDB                                                        |
| [`feedwatch-api`](https://github.com/ayenisholah/feedwatch-api)       | Rust (Axum)                        | Read API over InfluxDB                                                                                                        |
| [`feedwatch-web`](https://github.com/ayenisholah/feedwatch-web)       | TypeScript (Next.js static export) | Browser client, Frox design system                                                                                            |

Clone them side by side in one folder. On a new machine, clone this repo, then run `FEEDWATCH_HOME=. feedwatch-platform/scripts/bootstrap.sh` from that folder. It clones the other three and installs their git hooks.

## Local stack

```sh
cp .env.example .env      # then set real values
docker compose up -d --build   # InfluxDB :8086, Grafana :3001, poller /health :8081 (all on 127.0.0.1)
```

## Docs

- [Specification](SPEC.md) and [requirements](docs/REQUIREMENTS.md)
- [Roadmap](docs/ROADMAP.md) and [progress](docs/PROGRESS.md)
- [Engineering standards](docs/ENGINEERING_STANDARDS.md) and [test strategy](docs/TEST_STRATEGY.md)
- [Verified facts](docs/VERIFIED_FACTS.md): what the system relies on, and how it was checked
- [Data contract](docs/DATA_CONTRACT.md) and [deployment](docs/DEPLOYMENT.md)
- [Decisions](docs/adr/)

## Licence

MIT

# feedwatch-platform

The hub of [Feedwatch](SPEC.md), a monitor for RedStone's on-chain push price feeds. This repo holds the system docs, the data contract shared by the other repos, the local Compose stack, Grafana provisioning and the AWS deployment notes.

> **Status: scaffolded (M0).** No feed data yet. See [progress](docs/PROGRESS.md) and the [roadmap](docs/ROADMAP.md).

## Repos

| Repo                            | Language                           | Role                                                                                                                          |
| ------------------------------- | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `feedwatch-platform` (this one) | Docs, YAML                         | Specification, requirements, ADRs, [data contract](docs/DATA_CONTRACT.md), Compose, Grafana, [deployment](docs/DEPLOYMENT.md) |
| `feedwatch-poller`              | Rust                               | Reads every feed over public RPCs, runs the checks, writes to InfluxDB                                                        |
| `feedwatch-api`                 | Rust (Axum)                        | Read API over InfluxDB                                                                                                        |
| `feedwatch-web`                 | TypeScript (Next.js static export) | Browser client, Frox design system                                                                                            |

Clone them side by side in one folder. Run `bootstrap.sh` from that folder (not from this repo) to clone any repo that's missing.

## Local stack

```sh
cp .env.example .env      # then set real values
docker compose up -d      # InfluxDB on 127.0.0.1:8086, Grafana on 127.0.0.1:3001
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

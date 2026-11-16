# Feedwatch platform: agent instructions

This is the hub repo of Feedwatch, a monitor for RedStone on-chain push feeds. The system is split across four sibling repos in the same parent folder: `feedwatch-platform`, `feedwatch-poller`, `feedwatch-api` and `feedwatch-web`.

## Start of every session

1. Read [`docs/PROGRESS.md`](docs/PROGRESS.md). It gives the current milestone and the next step, and names which repo it's in.
2. Read that repo's `AGENTS.md` and `docs/PROGRESS.md`.
3. Before relying on any external interface, check [`docs/VERIFIED_FACTS.md`](docs/VERIFIED_FACTS.md).

## Rules for every repo

- [Engineering standards](docs/ENGINEERING_STANDARDS.md) and the [test strategy](docs/TEST_STRATEGY.md).
- Rust runs every server and worker; TypeScript is only in the browser client ([ADR 0002](docs/adr/0002-rust-server-typescript-client.md)).
- Repos share data only through the [data contract](docs/DATA_CONTRACT.md). Change the contract here first.
- Work traces to a requirement ID in [requirements](docs/REQUIREMENTS.md). If there isn't one, add it here first, or ask.
- Branch and pull request for every change. `main` is protected by a pre-push hook.
- **Commits and pull requests carry no tool attribution**: no `Co-Authored-By`, and no "Generated with". commitlint enforces this.
- AWS work goes through the AWS MCP, following [deployment](docs/DEPLOYMENT.md). Check prices first, and get the owner's OK before creating anything.

## Commands (this repo)

```sh
docker compose --env-file .env.example config --quiet   # validate the local stack
docker compose up -d                                     # run InfluxDB and Grafana (needs .env)
npx prettier --check .                                   # formatting
```

## Progress log

Update `docs/PROGRESS.md` in the same commit as the work: what's done, what's in progress, the exact next step, and what's blocked. A cold session should be able to resume from it alone.

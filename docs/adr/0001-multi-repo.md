# 0001: Four repositories

**Status:** Accepted, 2026-11-16.

## Context

Feedwatch has a Rust worker, a Rust API, a TypeScript client, and shared system docs and deployment. The owner asked for a multi-repo layout.

## Decision

Use four repos: `feedwatch-platform` (docs, data contract, Compose, Grafana, AWS notes), `feedwatch-poller`, `feedwatch-api` and `feedwatch-web`. They share data only through the versioned [data contract](../DATA_CONTRACT.md), never through code imports.

## Consequences

- Each repo has its own CI, toolchain and release cadence.
- A contract change takes several pull requests: release the contract first, then update each consumer.
- System-wide docs live in one place, the platform repo. Each repo keeps its own `docs/PROGRESS.md`.

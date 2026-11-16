# 0004: Vendor RedStone's manifests

**Status:** Accepted, 2026-11-16.

## Context

The feed list and its update rules come from RedStone's relayer manifests on GitHub. Fetching them at runtime would make the poller's behaviour change without a commit, and would fail if GitHub were unreachable.

## Decision

Copy the three manifests into `feedwatch-poller/manifests/`, recording the source commit in `manifests/SOURCE.md`. A script, `scripts/sync-manifests.sh`, refreshes them in a normal pull request.

## Consequences

- Behaviour is reproducible and reviewable.
- The list can fall behind RedStone's. Refresh it before a demo, and note the commit date in the README.

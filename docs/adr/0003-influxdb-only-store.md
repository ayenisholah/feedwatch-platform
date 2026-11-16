# 0003: InfluxDB as the only store

**Status:** Accepted, 2026-11-16.

## Context

Almost everything Feedwatch stores is a time series: feed values, ages, check results and RPC latency. Incidents are events in time. A second database would only hold the latest snapshot and incidents.

## Decision

Use InfluxDB 2 alone. The latest state is the last point per series. Incidents are `open` and `close` events in an `incident` measurement, linked by `incident_id`.

## Consequences

- Grafana reads the same data the API serves.
- "Open incidents" is a Flux query (the last event per `incident_id` is `open`), not a row lookup.
- If relational needs appear, such as user accounts, revisit this.

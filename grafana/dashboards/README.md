# Dashboards

Dashboard JSON files go here, exported from Grafana with "Export for sharing externally" turned off, so the datasource UID stays `feedwatch-influx`.

The first dashboard, `feeds.json`, comes in M1 (`feat/grafana-dashboard`, FR-FW-8). Its panels: age against heartbeat per feed, reference deviation, RPC latency and errors by provider, and poll cycle duration.

"""Builds grafana/dashboards/feeds.json, the provisioned Feedwatch dashboard (FR-FW-8).

Run `python3 grafana/build-dashboard.py` after editing; commit both files. The queries read the
measurements in contracts/influx-schema.json.
"""

import json
from pathlib import Path

DS = {"type": "influxdb", "uid": "feedwatch-influx"}
CHAINS = 'contains(value: r.chain, set: ${chain:json})'

AGE_VS_HEARTBEAT = f"""age = from(bucket: "feedwatch")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "feed_round" and r._field == "age_s" and {CHAINS})
  |> last() |> keep(columns: ["chain", "feed_id", "_value"]) |> rename(columns: {{_value: "age"}})
hb = from(bucket: "feedwatch")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "feed_check" and r._field == "heartbeat_s" and {CHAINS})
  |> last() |> keep(columns: ["chain", "feed_id", "_value"]) |> rename(columns: {{_value: "heartbeat"}})
join(tables: {{a: age, h: hb}}, on: ["chain", "feed_id"])
  |> map(fn: (r) => ({{chain: r.chain, feed: r.feed_id, "age (h)": float(v: r.age) / 3600.0,
                      "heartbeat (h)": float(v: r.heartbeat) / 3600.0,
                      "% of heartbeat": float(v: r.age) / float(v: r.heartbeat) * 100.0}}))
  |> group() |> sort(columns: ["% of heartbeat"], desc: true) |> limit(n: 25)"""

STATUS = f"""from(bucket: "feedwatch")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "feed_check" and r._field == "heartbeat_s" and {CHAINS})
  |> group(columns: ["chain", "feed_id"]) |> last()
  |> group() |> filter(fn: (r) => r.status != "ok")
  |> keep(columns: ["_time", "chain", "feed_id", "status"])"""

INCIDENTS = f"""from(bucket: "feedwatch")
  |> range(start: -30d)
  |> filter(fn: (r) => r._measurement == "incident" and {CHAINS})
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> group() |> sort(columns: ["_time"], desc: true)
  |> keep(columns: ["_time", "chain", "feed_id", "kind", "event", "detail", "incident_id"])"""

DEVIATION = f"""from(bucket: "feedwatch")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "feed_check" and r._field == "reference_deviation_pct" and {CHAINS})
  |> group(columns: ["chain", "feed_id"])
  |> aggregateWindow(every: v.windowPeriod, fn: max, createEmpty: false)
  |> map(fn: (r) => ({{r with _field: r.feed_id + " on " + r.chain}}))"""

RPC_LATENCY = f"""from(bucket: "feedwatch")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "rpc_call" and r._field == "latency_ms" and {CHAINS})
  |> group(columns: ["provider"])
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)"""

RPC_ERRORS = f"""from(bucket: "feedwatch")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "rpc_call" and r._field == "ok" and {CHAINS})
  |> map(fn: (r) => ({{r with _value: if r._value then 0.0 else 100.0}}))
  |> group(columns: ["provider"])
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)"""


def cycle(field: str) -> str:
    return f"""from(bucket: "feedwatch")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "poll_cycle" and r._field == "{field}")"""


def last_cycle(field: str) -> str:
    return cycle(field) + "\n  |> last()"


OPEN_INCIDENTS = """from(bucket: "feedwatch")
  |> range(start: -30d)
  |> filter(fn: (r) => r._measurement == "incident" and r._field == "incident_id")
  |> group(columns: ["_value"]) |> sort(columns: ["_time"]) |> last()
  |> group() |> filter(fn: (r) => r.event == "open") |> count()"""


def panel(pid, title, kind, query, grid, **extra):
    p = {
        "id": pid,
        "type": kind,
        "title": title,
        "datasource": DS,
        "gridPos": dict(zip("xywh", grid)),
        "targets": [{"refId": "A", "datasource": DS, "query": query}],
    }
    p.update(extra)
    return p


def stat(pid, title, query, x, unit="none", red_above=None):
    steps = [{"color": "green", "value": None}]
    if red_above is not None:
        steps.append({"color": "red", "value": red_above})
    return panel(
        pid, title, "stat", query, (x, 0, 6, 4),
        fieldConfig={"defaults": {"unit": unit, "thresholds": {"mode": "absolute", "steps": steps}}, "overrides": []},
        options={"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False}, "colorMode": "value"},
    )


def series(pid, title, query, grid, unit):
    return panel(pid, title, "timeseries", query, grid, fieldConfig={"defaults": {"unit": unit}, "overrides": []})


panels = [
    stat(1, "Feeds checked", last_cycle("feeds"), 0),
    stat(2, "Feeds not ok", last_cycle("failed_feeds"), 6, red_above=1),
    stat(3, "Open incidents", OPEN_INCIDENTS, 12, red_above=1),
    stat(4, "Last cycle", last_cycle("duration_ms"), 18, unit="ms", red_above=10000),
    panel(5, "Closest to their heartbeat", "table", AGE_VS_HEARTBEAT, (0, 4, 14, 10),
          fieldConfig={"defaults": {"decimals": 1, "thresholds": {"mode": "absolute", "steps": [
              {"color": "green", "value": None}, {"color": "orange", "value": 80}, {"color": "red", "value": 110}]}},
              "overrides": [{"matcher": {"id": "byName", "options": "% of heartbeat"},
                             "properties": [{"id": "custom.cellOptions", "value": {"type": "color-background"}}]}]}),
    panel(6, "Feeds not ok now", "table", STATUS, (14, 4, 10, 10)),
    series(7, "Distance from reference price (ETH, BTC, USDC)", DEVIATION, (0, 14, 12, 8), "percent"),
    series(8, "RPC latency by provider", RPC_LATENCY, (12, 14, 12, 8), "ms"),
    series(9, "RPC failed requests by provider", RPC_ERRORS, (0, 22, 12, 8), "percent"),
    series(10, "Poll cycle duration", cycle("duration_ms"), (12, 22, 12, 8), "ms"),
    panel(11, "Incidents (30 days)", "table", INCIDENTS, (0, 30, 24, 9)),
]

dashboard = {
    "uid": "feedwatch-feeds",
    "title": "Feedwatch: RedStone push feeds",
    "description": "Freshness, missed updates and RPC health for RedStone push feeds on Ethereum, Arbitrum and Base.",
    "tags": ["feedwatch", "redstone"],
    "timezone": "utc",
    "refresh": "1m",
    "schemaVersion": 39,
    "time": {"from": "now-6h", "to": "now"},
    "templating": {"list": [{
        "name": "chain", "label": "Chain", "type": "custom", "multi": True, "includeAll": False,
        "query": "ethereum,arbitrum,base",
        "current": {"text": ["ethereum", "arbitrum", "base"], "value": ["ethereum", "arbitrum", "base"]},
        "options": [{"text": c, "value": c, "selected": True} for c in ["ethereum", "arbitrum", "base"]],
    }]},
    "panels": panels,
}

out = Path(__file__).parent / "dashboards" / "feeds.json"
out.write_text(json.dumps(dashboard, indent=2) + "\n")
print(f"wrote {out} with {len(panels)} panels")

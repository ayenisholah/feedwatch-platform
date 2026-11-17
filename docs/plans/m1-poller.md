# M1 plan: a poller that writes real feed data to InfluxDB

**Status:** approved 2026-11-17, not started. Branches are in order; each is one pull request.

## Context

M0 is done: four public repos, CI passing. M1 makes `feedwatch-poller` do its job. Every 60 s it reads all 146 RedStone push feeds on Ethereum, Arbitrum and Base, checks freshness and missed updates, and writes results to InfluxDB. A provisioned Grafana dashboard shows them. When M1 ends there's a working monitor to show, locally, before the API, web and AWS work.

Code today: `feedwatch-poller/src/manifest.rs` parses the vendored manifests (`RawManifest`, `RawTriggers`, `Chain::{ALL, as_str, vendored_manifest}`). The other modules are doc-comment stubs. The data contract is fixed in `feedwatch-platform/contracts/influx-schema.json` and `docs/DATA_CONTRACT.md`, and the requirements are FR-FW-1 to 5, FR-FW-8, NFR-1 and NFR-2.

**Found while planning (manifest survey):**

- Of 146 feeds, 38 use the 24 h / 0.5% defaults.
- Overrides set heartbeats of 1, 2, 6, 12 and 24 h.
- One Arbitrum feed overrides only its heartbeat.
- Four Ethereum feeds (`mzUSD_*`, `mzPRIME_*`) have **`cron` overrides** (`"0 10 * * *"`, `"5 12 * * *"`) instead of a heartbeat or deviation. The plan handles them below.

## Order: one branch and one PR each, following the `feature-slice` skill

Every branch: start with a failing test named after the requirement, then implement, run `./scripts/check.sh` (coverage ≥95%), update `docs/PROGRESS.md`, and open a PR that merges once green. Commits carry no attribution.

### 0. `chore/dependabot-triage` (all repos, about 30 min)

- Merge the GitHub Actions bumps whose CI passes.
- Rust repos: close the `rust:1.100` image PR. Add a Dependabot `ignore` for the `rust` image, because the image must move together with `rust-toolchain.toml`.
- Web: close the `@types/node` 26 PR and ignore its semver-major updates (Node 24). Check whether `eslint-config-next` 16.4 supports TypeScript 7 and ESLint 10; if it doesn't, close those PRs and add ignores. Take jsdom 31 if CI passes.

### 1. `feat/manifest` (FR-FW-1) in `src/manifest.rs`

- `Feed { chain, id, address: Address, schedule: Schedule }`, where:
  - `Schedule::Triggers { heartbeat: Duration, deviation_pct: f64 }` is the defaults with the overrides merged field by field;
  - `Schedule::Cron { expressions, period: Duration }` is used when the override has `cron`.
- `Address` is a newtype that only parses `0x` plus 40 hex characters.
- `load_feeds(chain) -> Result<Vec<Feed>, ManifestError>`.
- Cron: accept only daily expressions (`M H * * *`), with period 24 h. Anything else is a `ManifestError::UnsupportedCron` naming the feed, so a manifest refresh with a new cron form fails the tests loudly.
- Tests:
  - `LBTC_FUNDAMENTAL` has its override (1%, 24 h);
  - `USD3` gets the defaults;
  - the Arbitrum heartbeat-only override keeps the default deviation;
  - `mzUSD_FUNDAMENTAL` is `Cron`, 24 h;
  - a bad address and a non-daily cron are rejected;
  - the counts are 95, 21 and 30.
- Docs: add fact F-14 to `VERIFIED_FACTS.md`: "`cron` feeds update on schedule; Feedwatch treats them as a 24 h heartbeat with no deviation check". Status `documented` from the manifest, behaviour `unknown` until observed.

### 2. `feat/abi` (part of FR-FW-2) in `src/abi.rs`

- Pure functions:
  - `LATEST_ROUND_DATA = "0xfeaf968c"` and `DECIMALS = "0x313ce567"`;
  - `decode_round(hex) -> Result<Round, AbiError>` where `Round { round_id: u128, answer: i128, updated_at: u64 }`;
  - `decode_decimals(hex) -> u8`.
- int256 decoding: two's complement from 32 bytes. Reject values that don't fit in i128, results shorter than 5 words, odd-length or non-hex text, and negative answers. Prices are never negative, so a negative answer is reported as a `NegativeAnswer` error, not a value.
- `Round::scaled(decimals) -> f64`, keeping `answer_raw` as a string for the contract.
- Fixtures: the real `eth_call` results recorded on 2026-11-16 (F-1, F-10), saved as `tests/fixtures/*.hex`.

### 3. `feat/rpc` (FR-FW-2, NFR-1) in `src/rpc.rs` and `src/config.rs`

- `trait RpcTransport { async fn post(&self, url, body) -> Result<Vec<u8>, TransportError> }`, with a reqwest implementation (rustls, 5 s timeout).
- `RpcClient::call_batch(chain, calls) -> Vec<Result<String, CallError>>`:
  - split into chunks of at most 20 `eth_call`s and send them as JSON-RPC arrays;
  - match responses by `id`, not by order;
  - retry twice with backoff (200 ms, then 800 ms) on transport errors or 429/5xx;
  - then fail over to the next provider for that chunk;
  - record one `RpcCallStat { chain, provider_host, latency_ms, ok, calls }` per request.
- `config.rs`: parse `FEEDWATCH_RPC_{ETHEREUM,ARBITRUM,BASE}` (comma-separated URLs, at least one each), `FEEDWATCH_POLL_INTERVAL_SECS` (default 60) and `INFLUX_*`. It's a validated `Config`, and errors name the variable.
- Tests use `wiremock` (dev-dependency):
  - FR-FW-2: provider A returns 500 and B succeeds, so every call is answered;
  - responses out of order;
  - a single call's error object becomes that call's error;
  - a 45-call batch is sent as 3 requests (NFR-1).
- Live check (manual, recorded as F-12): send batches of 20, 50 and 100 to publicnode and note the largest that works and any 429s.

### 4. `feat/checks` (FR-FW-3, FR-FW-4) in `src/checks.rs`, pure

- `assess(feed, round: Option<&Round>, reference: Option<Reference>, now) -> Assessment { status, age_s, reference_deviation_pct }`, where `status` is `Ok`, `Stale`, `Drift` or `Error`.
- Rules (SPEC.md):
  - `Stale` when age > heartbeat × 1.1 (cron feeds use their period);
  - `Drift` when |reference − value| / reference × 100 > deviation_pct and age > 600 s, for trigger feeds with a reference;
  - `Error` when there's no round;
  - `Stale` wins over `Drift`.
- `IncidentTracker`: in-memory `HashMap<(chain, id), OpenIncident>`. `observe(feed, status, now) -> Option<IncidentEvent>` produces `open` on leaving `Ok` and `close` on returning. `incident_id = "{chain}:{id}:{opened_unix}"`, which needs no uuid crate. A change between non-ok kinds closes one incident and opens another.
- `spread(values) -> f64`, `(max − min) / median`, for the API's compare in M2. Kept here because it's pure and tested once.
- Tests:
  - boundaries for both rules, just inside and just outside;
  - `Drift` doesn't fire within 10 minutes;
  - cron feeds skip the drift rule;
  - incident open, close, and a kind change.

### 5. `feat/reference` (FR-FW-4) in `src/reference.rs`

- Reference pairs: ETH, BTC and USDC.
- Chainlink on Ethereum mainnet, read through the same `RpcClient` and `abi`:
  - ETH/USD `0x5f4e…8419` (F-6);
  - BTC/USD `0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c` and USDC/USD `0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6` — **check both live first and add them as F-15 and F-16**.
- Coinbase: `GET https://api.coinbase.com/v2/prices/{ETH,BTC,USDC}-USD/spot` (F-7).
- Choice: use Chainlink when its update is under 1 h old, otherwise Coinbase. Record `reference_source` (`chainlink` or `coinbase`). If both fail there's no reference, and the drift check is skipped for that cycle.
- Applies to feed IDs exactly `ETH`, `BTC` and `USDC` on every chain.
- 30 s cache, with time injected.
- Tests: wiremock for Coinbase, a fake transport for Chainlink, the stale-Chainlink fallback, and both sources down.

### 6. `feat/influx-sink` (FR-FW-5) in `src/influx.rs`

- `line_protocol(points) -> String`, pure: escapes tags, quotes and escapes strings, writes `i` suffixes on ints, seconds precision. It follows `influx-schema.json` v1: `feed_round`, `feed_check`, `rpc_call`, `incident` and `poll_cycle`.
- `trait InfluxWriter { async fn write(&self, lines: &str) }`. The HTTP implementation sends `POST /api/v2/write?org=&bucket=&precision=s` with `Authorization: Token …`.
- `load_open_incidents(&self) -> Vec<OpenIncident>`: one Flux query at startup (the last `incident` event per `incident_id` where it's `open`), so a restart doesn't duplicate incidents.
- Tests:
  - snapshot tests of line protocol for every measurement;
  - a contract test that loads `../feedwatch-platform/contracts/influx-schema.json` when present, or a copy vendored at `tests/fixtures/influx-schema.v1.json` (CI has only this repo), and checks that each written measurement uses exactly the contract's tags and fields;
  - `testcontainers` with `influxdb:2.9.1`: write, then query back, and restart recovery of open incidents. Marked `#[ignore]` locally and run in CI with `cargo test -- --include-ignored`. This needs a CI tweak to `scripts/check.sh` (a `CI=1` branch).

### 7. `feat/poll-loop` (NFR-1, NFR-2) in `src/poller.rs` and `src/main.rs`

- `Poller::cycle(now)` runs:
  1. per chain (concurrently), a batch of `latestRoundData` for all feeds, with `decimals` cached after the first success;
  2. references;
  3. `assess`;
  4. incidents;
  5. one Influx write per cycle.
     It returns a `CycleReport { duration_ms, feeds, failed_feeds, failed }`.
- `failed` is true when any chain had no provider answer, or when the Influx write failed.
- Each cycle logs one EMF JSON line: `_aws.CloudWatchMetrics` with namespace `Feedwatch` and metric `PollCycleFailed` (0 or 1), plus `durationMs`. Recorded as a `documented` fact for M4, to be proven there.
- `main.rs`: Tokio `interval` (`MissedTickBehavior::Skip`), graceful shutdown on Ctrl-C or SIGTERM. Axum on `FEEDWATCH_HEALTH_ADDR` (default `0.0.0.0:8081`):
  - `/health` returns 200 when the last successful cycle was less than 3 intervals ago, otherwise 503;
  - `/metrics` gives the last cycle report in Prometheus text format.
- Tests:
  - a cycle with fake RPC and writer gives the expected points;
  - one chain fully down sets `failed` while the other chains are still written;
  - health flips to 503 after 3 missed intervals (fake clock);
  - NFR-1 timing: 146 feeds through wiremock with 50 ms latency finish in under 10 s.
- Uncomment `poller` in platform `compose.yaml`, built locally (`image: feedwatch-poller:local`, `build: ../feedwatch-poller`). That's a separate platform PR.

### 8. Platform `feat/grafana-dashboard` (FR-FW-8)

- `grafana/dashboards/feeds.json` with chain and feed variables. Panels:
  - age as a percentage of heartbeat, by feed;
  - status table (latest `feed_check`);
  - reference deviation against threshold;
  - open incidents;
  - RPC latency and error rate by provider;
  - poll cycle duration.
- Built in local Grafana against real data, exported, and committed.
- Compose smoke check: datasource health is OK and the dashboard API returns the UID.

### 9. Close M1

- Run the stack for at least 2 h against the public RPCs.
- Record real findings in platform `docs/PROGRESS.md` and the poller README: observed update cadence against configured heartbeats, any stale or drift incidents, the largest batch size that worked, and cycle duration.
- Mark FR-FW-1 to 5, FR-FW-8, NFR-1 and NFR-2 as `done` in `REQUIREMENTS.md` with test names, and mark M1 done in `ROADMAP.md`.
- Set the next step to M2 `feat/influx-client`.

## Dependencies added (poller)

`tokio` (rt-multi-thread, macros, time, signal), `reqwest` 0.13 (default-features off; json, rustls), `axum` 0.8, `async-trait` if needed (Rust 2024 async fn in traits may be enough), and `serde`/`serde_json` (already present). Dev: `wiremock`, `testcontainers`, `insta` (snapshots). Each must pass `cargo deny`; extend the licence allow-list only if a licence is permissive and the reason is recorded.

## Critical files

- Poller: `src/{manifest,abi,rpc,config,checks,reference,influx,poller,main}.rs`, `tests/*.rs`, `tests/fixtures/`, `Cargo.toml`, `scripts/check.sh`, `.env.example`, `docs/PROGRESS.md`, `README.md`.
- Platform: `docs/{VERIFIED_FACTS,REQUIREMENTS,ROADMAP,PROGRESS}.md`, `compose.yaml`, `grafana/dashboards/feeds.json`.

## Estimate

About 2–3 working days. Branches 1–4 are pure logic and quick; 5–7 hold most of the I/O and testing; 8–9 take half a day plus the 2 h soak.

## Verification

- Every PR: `./scripts/check.sh` green locally and in CI, coverage ≥95%, and InfluxDB integration tests run in CI.
- End to end: in platform, `docker compose up -d --build`. Within 60 s, `curl localhost:8081/health` returns 200. In InfluxDB, `from(bucket:"feedwatch") |> range(start:-5m) |> filter(fn:(r)=>r._measurement=="feed_round") |> group(columns:["chain"]) |> count()` returns 95, 21 and 30 series. The Grafana dashboard shows all three chains.
- Spot check: the ETH feed's `value` and `updated_at` on each chain match a manual `eth_call` of `latestRoundData` at the same moment.
- Failure path: set `FEEDWATCH_RPC_BASE` to a dead URL plus publicnode. Feeds stay `ok` through failover, and `rpc_call` shows the dead provider's errors. Set it to only the dead URL: Base feeds become `error`, an incident opens, the cycle is `failed`, and the EMF line shows `PollCycleFailed: 1`. Restore it, and the incidents close.

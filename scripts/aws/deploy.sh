#!/usr/bin/env bash
# Deploys or redeploys Feedwatch on the EC2 host. Run as root, by user data at first boot and by
# SSM Run Command afterwards (docs/DEPLOYMENT.md). Idempotent.
#
# BUILD=ecr (the target): images come from ECR and the site from S3, both published by CodeBuild.
# BUILD=host (the default until the CodeBuild quota is raised, ADR 0007): this arm64 host builds the
# images and the static site itself from the public repos at main.
set -euo pipefail
export AWS_REGION=eu-north-1 AWS_DEFAULT_REGION=eu-north-1
APP=/opt/feedwatch
cd "$APP/platform"
git pull --ff-only --quiet

param() { aws ssm get-parameter --name "$1" ${2:+--with-decryption} --query Parameter.Value --output text; }

SITE_URL=$(param /feedwatch/site/url)
export SITE_URL

# Runtime configuration. Each service gets its own env file (mode 600) with only what it needs:
# the InfluxDB admin token and passwords reach InfluxDB and Grafana only, and the poller and API
# get bucket-scoped tokens (influx_tokens below). Nothing here is printed.
umask 077
ADMIN_TOKEN=$(param /feedwatch/influx/token secure)
# write_env FILE: writes stdin to $APP/FILE atomically.
write_env() { cat > "$APP/$1.tmp" && mv "$APP/$1.tmp" "$APP/$1"; }
write_env .env.influxdb <<ENV
DOCKER_INFLUXDB_INIT_MODE=setup
DOCKER_INFLUXDB_INIT_USERNAME=feedwatch
DOCKER_INFLUXDB_INIT_PASSWORD=$(param /feedwatch/influx/password secure)
DOCKER_INFLUXDB_INIT_ORG=feedwatch
DOCKER_INFLUXDB_INIT_BUCKET=feedwatch
DOCKER_INFLUXDB_INIT_RETENTION=30d
DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=$ADMIN_TOKEN
ENV
# Compose reads every service's env_file on any command, so they must exist before the first one.
for f in .env.poller .env.api .env.grafana; do [ -f "$APP/$f" ] || : > "$APP/$f"; done
umask 022

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY="$ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com"
export TAG="${TAG:-latest}"
export SITE_ADDRESS="$(param /feedwatch/site/address 2>/dev/null || echo :80)"

BUILD="${BUILD:-$(param /feedwatch/build/mode 2>/dev/null || echo host)}"
mkdir -p "$APP/site" "$APP/src"

checkout() {
  local repo=$1 dir="$APP/src/$1"
  if [ -d "$dir/.git" ]; then git -C "$dir" pull --ff-only --quiet; else git clone --quiet --depth 1 "https://github.com/ayenisholah/$repo" "$dir"; fi
}

if [ "$BUILD" = "host" ]; then
  for repo in feedwatch-poller feedwatch-api; do
    checkout "$repo"
    docker build --quiet -t "$REGISTRY/$repo:$TAG" "$APP/src/$repo" >/dev/null
  done
  checkout feedwatch-web
  docker run --rm -v "$APP/src/feedwatch-web:/app" -w /app node:24-alpine \
    sh -c "npm ci --no-audit --no-fund --ignore-scripts >/dev/null && npx next build >/dev/null"
  # Replace the contents, not the directory: the router bind-mounts $APP/site, and a renamed
  # directory would leave it serving the deleted one.
  find "$APP/site" -mindepth 1 -delete
  cp -a "$APP/src/feedwatch-web/out/." "$APP/site/"
  docker compose -f compose.aws.yaml pull --quiet router influxdb grafana
else
  aws s3 sync "s3://$(param /feedwatch/site/bucket)" "$APP/site" --delete --only-show-errors
  aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRY" >/dev/null
  docker compose -f compose.aws.yaml pull --quiet
fi

# InfluxDB first: the scoped tokens are created through it.
docker compose -f compose.aws.yaml up -d influxdb
for _ in $(seq 1 60); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose -f compose.aws.yaml ps -q influxdb)")" = healthy ] && break
  sleep 2
done

# influx ARGS...: the influx CLI inside the InfluxDB container, as the admin. The token goes in
# through the environment, not the command line.
influx() { docker compose -f compose.aws.yaml exec -T -e INFLUX_TOKEN="$ADMIN_TOKEN" influxdb influx "$@"; }
json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

# influx_tokens: sets READ_TOKEN (API, Grafana: read the bucket) and POLLER_TOKEN (read and write
# the bucket). They're created once and kept in $APP/influx-tokens.env (mode 600), and recreated if
# InfluxDB no longer has them, such as after a fresh data volume.
influx_tokens() {
  local file="$APP/influx-tokens.env" bucket
  if [ -f "$file" ]; then
    # shellcheck disable=SC1090
    . "$file"
    if influx auth list --json | READ_TOKEN="$READ_TOKEN" POLLER_TOKEN="$POLLER_TOKEN" python3 -c '
import json, os, sys
active = {a["token"] for a in json.load(sys.stdin) if a.get("status") == "active"}
sys.exit(0 if {os.environ["READ_TOKEN"], os.environ["POLLER_TOKEN"]} <= active else 1)'; then
      return
    fi
  fi
  # Remove earlier copies by description, so tokens don't pile up.
  influx auth list --json |
    json '"\n".join(a["id"] for a in d if a.get("description", "").startswith("feedwatch-scoped:"))' |
    while read -r id; do
      # An if, not &&: a false test as the loop's last command would fail the pipeline under set -e.
      # </dev/null: exec would otherwise read the rest of the IDs from this loop's input.
      if [ -n "$id" ]; then influx auth delete --id "$id" >/dev/null </dev/null; fi
    done
  bucket=$(influx bucket list --org feedwatch --name feedwatch --json | json 'd[0]["id"]')
  READ_TOKEN=$(influx auth create --org feedwatch --read-bucket "$bucket" \
    --description "feedwatch-scoped: read (api, grafana)" --json | json '(d[0] if isinstance(d, list) else d)["token"]')
  POLLER_TOKEN=$(influx auth create --org feedwatch --read-bucket "$bucket" --write-bucket "$bucket" \
    --description "feedwatch-scoped: read and write (poller)" --json | json '(d[0] if isinstance(d, list) else d)["token"]')
  (umask 077 && printf 'READ_TOKEN=%s\nPOLLER_TOKEN=%s\n' "$READ_TOKEN" "$POLLER_TOKEN" > "$file")
}
influx_tokens

umask 077
write_env .env.poller <<ENV
RUST_LOG=info
FEEDWATCH_RPC_ETHEREUM=$(param /feedwatch/rpc/ethereum)
FEEDWATCH_RPC_ARBITRUM=$(param /feedwatch/rpc/arbitrum)
FEEDWATCH_RPC_BASE=$(param /feedwatch/rpc/base)
FEEDWATCH_POLL_INTERVAL_SECS=60
INFLUX_URL=http://influxdb:8086
INFLUX_ORG=feedwatch
INFLUX_BUCKET=feedwatch
INFLUX_TOKEN=$POLLER_TOKEN
ENV
write_env .env.api <<ENV
RUST_LOG=info
INFLUX_URL=http://influxdb:8086
INFLUX_ORG=feedwatch
INFLUX_BUCKET=feedwatch
INFLUX_TOKEN=$READ_TOKEN
# The API allows CORS only from the site itself (GR-2).
FEEDWATCH_ALLOWED_ORIGIN=$SITE_URL
ENV
write_env .env.grafana <<ENV
GF_SECURITY_ADMIN_PASSWORD=$(param /feedwatch/grafana/admin-password secure)
INFLUX_TOKEN=$READ_TOKEN
ENV
umask 022
# The old shared file held every secret; nothing reads it any more.
rm -f "$APP/.env"

docker compose -f compose.aws.yaml up -d --remove-orphans
# The Caddyfile is a bind mount, so apply any change to it without restarting the router.
docker compose -f compose.aws.yaml exec -T router caddy reload --config /etc/caddy/Caddyfile >/dev/null
docker image prune -f >/dev/null
# Host builds leave Docker build cache behind; unpruned it filled the 20 GB disk to 99% by
# 2026-11-18. Keep 3 GB, enough for fast incremental builds.
docker builder prune -f --keep-storage 3gb >/dev/null
docker compose -f compose.aws.yaml ps --format '{{.Service}} {{.State}}'

# Fail the deploy, so the Actions run shows it, while there's still room to act.
used=$(df --output=pcent / | tail -1 | tr -dc '0-9')
echo "disk ${used}% used"
if [ "$used" -gt 85 ]; then
  echo "disk is ${used}% full (over 85%): free space on the host" >&2
  exit 1
fi

#!/usr/bin/env bash
# Deploys or redeploys Feedwatch on the EC2 host. Run as root, by user data at first boot and by
# SSM Run Command afterwards (docs/DEPLOYMENT.md). Idempotent.
set -euo pipefail
export AWS_REGION=eu-north-1 AWS_DEFAULT_REGION=eu-north-1
APP=/opt/feedwatch
cd "$APP/platform"
git pull --ff-only --quiet

param() { aws ssm get-parameter --name "$1" ${2:+--with-decryption} --query Parameter.Value --output text; }

# Runtime configuration, from SSM Parameter Store. Secrets stay on the host, mode 600.
umask 077
INFLUX_TOKEN=$(param /feedwatch/influx/token secure)
cat > "$APP/.env.tmp" <<ENV
RUST_LOG=info
FEEDWATCH_RPC_ETHEREUM=$(param /feedwatch/rpc/ethereum)
FEEDWATCH_RPC_ARBITRUM=$(param /feedwatch/rpc/arbitrum)
FEEDWATCH_RPC_BASE=$(param /feedwatch/rpc/base)
FEEDWATCH_POLL_INTERVAL_SECS=60
INFLUX_URL=http://influxdb:8086
INFLUX_ORG=feedwatch
INFLUX_BUCKET=feedwatch
INFLUX_TOKEN=$INFLUX_TOKEN
DOCKER_INFLUXDB_INIT_MODE=setup
DOCKER_INFLUXDB_INIT_USERNAME=feedwatch
DOCKER_INFLUXDB_INIT_PASSWORD=$(param /feedwatch/influx/password secure)
DOCKER_INFLUXDB_INIT_ORG=feedwatch
DOCKER_INFLUXDB_INIT_BUCKET=feedwatch
DOCKER_INFLUXDB_INIT_RETENTION=30d
DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=$INFLUX_TOKEN
GF_SECURITY_ADMIN_PASSWORD=$(param /feedwatch/grafana/admin-password secure)
ENV
mv "$APP/.env.tmp" "$APP/.env"
umask 022

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY="$ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com"
export TAG="${TAG:-latest}"
export SITE_ADDRESS="$(param /feedwatch/site/address 2>/dev/null || echo :80)"
export SITE_URL="$(param /feedwatch/site/url)"

# The web client's static export, published to S3 by CodeBuild.
mkdir -p "$APP/site"
aws s3 sync "s3://$(param /feedwatch/site/bucket)" "$APP/site" --delete --only-show-errors

aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRY" >/dev/null
docker compose -f compose.aws.yaml pull --quiet
docker compose -f compose.aws.yaml up -d --remove-orphans
docker image prune -f >/dev/null
docker compose -f compose.aws.yaml ps --format '{{.Service}} {{.State}}'

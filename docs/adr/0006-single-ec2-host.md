# 0006: One EC2 host, with the client on S3 and CloudFront

**Status:** Accepted, 2026-11-16. Amended by [0007](0007-codebuild-and-caddy.md): CloudFront is pending account verification, so Caddy on the host serves everything for now.

## Context

The options were ECS on Fargate behind a load balancer, with Amazon Timestream for InfluxDB and Amazon Managed Grafana, or one EC2 host running Docker Compose. The owner chose the lean, self-hosted option. The managed setup was estimated at $80 or more a month, against roughly $15–20 for one host.

## Decision

- One t4g.small runs the poller, API, InfluxDB, Grafana and an nginx router in Docker Compose.
- The client is on S3 behind CloudFront, which also proxies `/api/*` and `/grafana/*` to the host. That gives HTTPS on one domain without a load balancer.
- Access is through SSM Session Manager only, logs and alarms are in CloudWatch, and configuration is in SSM Parameter Store.

## Consequences

- One instance is a single point of failure, which is accepted for a public monitor. The CloudWatch status-check alarm reports outages.
- Data is on one EBS volume. Losing it loses at most 30 days of history, which the poller rebuilds from live data.

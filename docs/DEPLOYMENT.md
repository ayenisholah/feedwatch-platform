# Deployment on AWS

**Status:** live since 2026-11-17 at http://16.192.242.39 (site, `/api/health`, `/grafana/`). HTTPS waits on the domain; CloudFront waits on account verification. **Updated:** 2026-11-17

Feedwatch runs on AWS in **eu-north-1**, the only Region the account's service control policy allows for regional services. Everything is created and changed through the **AWS MCP** (`aws___run_script` with boto3) and the installed `aws-*` skills, without Terraform ([ADR 0005](adr/0005-no-terraform-aws-mcp.md)). It's one EC2 host ([ADR 0006](adr/0006-single-ec2-host.md)), built by CodeBuild and served by Caddy, because GitHub OIDC and CloudFront aren't available in this account yet ([ADR 0007](adr/0007-codebuild-and-caddy.md)).

## Rules

- Check prices first, with the `aws-billing-and-cost-management` skill and the Price List API, and get the owner's OK before creating billable resources. The owner approved this deployment on 2026-11-17.
- Tag every resource `project=feedwatch`. Each step looks its resource up by name or tag first, so it can safely run again.
- Keep the account ID and secrets out of this repo. Secrets are generated inside the AWS MCP sandbox and stored as SSM SecureString. They're written only to `/opt/feedwatch/.env` (mode 600) on the host.

## Cost

Priced on 2026-11-17 from the AWS Price List API (eu-north-1, on demand):

| Item                                     | Monthly    |
| ---------------------------------------- | ---------- |
| EC2 t4g.small, 730 h × $0.0172           | $12.56     |
| Public IPv4 (Elastic IP), 730 h × $0.005 | $3.65      |
| EBS gp3 20 GB × $0.0836                  | $1.67      |
| CloudWatch Logs, about 1 GB × $0.54      | $0.54      |
| CloudWatch alarms, 2 × $0.10             | $0.20      |
| ECR, about 1 GB × $0.10                  | $0.10      |
| **Priced total**                         | **$18.72** |

Not priced: custom metrics (3), CodeBuild minutes per deploy, and S3 requests. Budget `feedwatch-monthly` alerts at 80% of $25 actual and 100% forecast. It covers the whole account: a linked account can't activate cost allocation tags, and Feedwatch was the only spend when it was created.

## Resources

| #   | Resource                                                           | Detail                                                                                                                                                                             |
| --- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Budget `feedwatch-monthly`                                         | $25/month; filtered on the `project=feedwatch` cost allocation tag, which must be activated in Billing; emails the owner                                                           |
| 2   | SNS topic `feedwatch-alerts`                                       | Email subscription to the owner, who must click the confirmation link                                                                                                              |
| 3   | ECR `feedwatch-poller`, `feedwatch-api`                            | Scan on push, keep the last 10 images                                                                                                                                              |
| 4   | S3 site bucket                                                     | Private, versioned, public access blocked. Name in `/feedwatch/site/bucket`                                                                                                        |
| 5   | IAM role `feedwatch-host` and instance profile                     | SSM core, ECR read, read `/feedwatch/*` parameters and the site bucket, write `/feedwatch/*` logs                                                                                  |
| 6   | IAM role `feedwatch-build`                                         | CodeBuild: push to the two ECR repos, write the site bucket, write `/feedwatch/build` logs                                                                                         |
| 7   | Security group `feedwatch-host`                                    | 80 and 443 in from anywhere (Caddy); no SSH                                                                                                                                        |
| 8   | Elastic IP                                                         | The host's stable address                                                                                                                                                          |
| 9   | Log groups `/feedwatch/{poller,api,influxdb,grafana,router,build}` | 14-day retention                                                                                                                                                                   |
| 10  | SSM parameters                                                     | `/feedwatch/rpc/{ethereum,arbitrum,base}`, `/feedwatch/influx/{token,password}` and `/feedwatch/grafana/admin-password` (SecureString), and `/feedwatch/site/{bucket,url,address}` |
| 11  | CodeBuild project `feedwatch-build`                                | arm64, privileged, buildspec [`scripts/aws/buildspec.yml`](../scripts/aws/buildspec.yml)                                                                                           |
| 12  | EC2 `feedwatch-host`                                               | t4g.small, Amazon Linux 2023 arm64, 20 GB gp3 encrypted, IMDSv2 required, user data [`scripts/aws/host-bootstrap.sh`](../scripts/aws/host-bootstrap.sh)                            |
| 13  | CloudWatch alarms                                                  | `feedwatch-poll-cycle-failed` (EMF metric `Feedwatch/PollCycleFailed`, at least 3 in 5 minutes, or missing data) and `feedwatch-host-status` (EC2 status checks), both to SNS      |
| —   | CloudFront OAC `feedwatch-web`, function `feedwatch-index`         | Created; the distribution waits on account verification (ADR 0007)                                                                                                                 |

## The host

- `host-bootstrap.sh` installs Docker and Compose, adds 2 GB of swap, clones this repo to `/opt/feedwatch/platform` and runs `deploy.sh`.
- `deploy.sh`:
  - pulls this repo;
  - writes `/opt/feedwatch/.env` from SSM;
  - syncs the site bucket to `/opt/feedwatch/site`;
  - logs in to ECR;
  - runs `docker compose -f compose.aws.yaml pull && up -d`.
- [`compose.aws.yaml`](../compose.aws.yaml) runs Caddy (router), the poller, the API, InfluxDB and Grafana. Each logs to its CloudWatch log group through the awslogs driver.
- [`caddy/Caddyfile`](../caddy/Caddyfile) serves the site, `/api/*` and `/grafana*`. `SITE_ADDRESS` comes from `/feedwatch/site/address`: `:80` by default, and the domain once DNS points at the Elastic IP.

## Live check (2026-11-17)

- The first boot built everything on the host in about 29 minutes. The poller then checked 146 feeds per cycle in 554–640 ms, with Ethereum `USUAL` the one failing feed, as locally.
- `/` and `/compare/` return 200, unknown paths return 404, `/api/health` returns `{"status":"ok"}`, and `/grafana/` serves the provisioned dashboard to anonymous viewers.
- EMF metrics reached CloudWatch (fact F-18), and both alarms went `OK`.
- Two deploy bugs were found and fixed live: the 404 status (platform#14), and a stale bind mount after replacing the site directory (platform#15).

## Deploying a change

`/feedwatch/build/mode` selects how the host gets its artefacts. `host` (the default until the CodeBuild quota increase is granted, ADR 0007) builds them on the host from `main`; `ecr` uses what CodeBuild published. In `host` mode, skip step 1.

Through the AWS MCP:

1. `codebuild:StartBuild` on project `feedwatch-build` with `TARGET` = `poller`, `api` or `web` (and `REF`, default `main`). Wait for `SUCCEEDED`.
2. `ssm:SendCommand` with `AWS-RunShellScript` on the instance tagged `project=feedwatch`: `bash /opt/feedwatch/platform/scripts/aws/deploy.sh`.
3. Check: `GET /api/health` and Grafana `/grafana/api/health` on the site, `/health` on the poller through SSM (`curl localhost` inside the poller network), and the `feedwatch-poll-cycle-failed` alarm state.

## Custom domain and HTTPS (owner)

1. In Namecheap, add an A record `feedwatch` pointing to the Elastic IP (look it up in the EC2 console or the `/feedwatch/site/url` parameter).
2. Set `/feedwatch/site/address` to `feedwatch.sholaayeni.xyz` and `/feedwatch/site/url` to `https://feedwatch.sholaayeni.xyz`, then redeploy (step 2 above). Caddy obtains the certificate on its own.

## CloudFront later (owner)

Open an AWS Support case asking for CloudFront to be enabled for the account (quote "Your account must be verified before you can add new CloudFront resources"). Once it's enabled, a distribution can front the site bucket (through the existing OAC and index function) and the host for `/api/*` and `/grafana/*`.

## Teardown

Delete in reverse order: alarms, EC2 instance, Elastic IP (release), security group, CodeBuild project, log groups, SSM parameters under `/feedwatch/`, the site bucket (empty it first, including all versions), ECR repositories, IAM roles and instance profile, SNS topic, the budget, and the CloudFront OAC and function.

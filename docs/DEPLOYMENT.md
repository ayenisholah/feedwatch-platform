# Deployment on AWS

**Status:** planned for M4. Nothing has been created yet. **Updated:** 2026-11-16

Feedwatch runs on AWS, using the setup chosen on 2026-11-16 because it is lean and self-hosted. All resources are created and changed through the **AWS MCP** (`aws___run_script` with boto3), using the snippets in [`scripts/aws/`](../scripts/aws/), and without Terraform ([ADR 0005](adr/0005-no-terraform-aws-mcp.md), [ADR 0006](adr/0006-single-ec2-host.md)).

## Account and Region

Checked through the AWS MCP on 2026-11-17, read-only, as IAM user `claude-code`. The account ID stays out of this repo.

- **Region: eu-north-1 (Stockholm).** A service control policy explicitly denies regional services elsewhere. eu-central-1, eu-west-1, eu-west-2 and us-east-1 were denied for EC2 and ECR. t4g.small is offered in eu-north-1.
- Reads that worked: EC2 and ECR (eu-north-1), SSM Parameter Store, CloudWatch Logs, S3, CloudFront, ACM in us-east-1 (needed for the CloudFront certificate), IAM, Budgets.
- Denied by policy: `iam:ListAccountAliases` and `tag:GetResources`. So `00-preflight.py` can't list tagged resources through the tagging API; M4 snippets look resources up per service instead.
- Create permissions are untested. Check them with the first M4 step, after the owner's OK.

## Rules

- Check prices with the `aws-billing-and-cost-management` skill before creating anything, and get the owner's OK before each create step.
- Tag every resource `project=feedwatch`. Each snippet looks its resource up by name or tag before creating it, so it can safely run again.
- Keep the account ID, ARNs with the account ID, and secrets out of this repo. Write `<account>` in docs.
- `scripts/aws/90-teardown.py` removes every Feedwatch resource, found per service by name or tag.

## Resources

| #   | Resource                             | Detail                                                                                                                                                              |
| --- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | AWS Budgets                          | $25/month, email alert at 80% and 100%                                                                                                                              |
| 2   | ECR repositories                     | `feedwatch-poller`, `feedwatch-api`; scan on push; keep the last 10 images                                                                                          |
| 3   | SSM parameters                       | `/feedwatch/rpc/{ethereum,arbitrum,base}` (String, comma-separated provider URLs), `/feedwatch/influx/token` and `/feedwatch/grafana/admin-password` (SecureString) |
| 4   | IAM instance role                    | `AmazonSSMManagedInstanceCore`, ECR read, read on `/feedwatch/*` parameters, CloudWatch Logs write                                                                  |
| 5   | Security group                       | Inbound 80 only from the CloudFront origin-facing managed prefix list; no port 22                                                                                   |
| 6   | EC2 instance                         | t4g.small, Amazon Linux 2023 arm64, 20 GB gp3, IMDSv2 required, user data installs Docker and Compose                                                               |
| 7   | Elastic IP                           | Gives CloudFront a stable origin                                                                                                                                    |
| 8   | CloudWatch log groups                | `/feedwatch/poller`, `/feedwatch/api`, `/feedwatch/influxdb`, `/feedwatch/grafana`; 14-day retention                                                                |
| 9   | CloudWatch alarms                    | `PollCycleFailed ≥ 3 in 5 min` (EMF metric, namespace `Feedwatch`), and EC2 `StatusCheckFailed`; both to SNS topic `feedwatch-alerts` with email                    |
| 10  | S3 bucket                            | Private, versioned; holds the web client's static export                                                                                                            |
| 11  | ACM certificate                      | In us-east-1 for `feedwatch.sholaayeni.xyz`; DNS validation record added in Namecheap by the owner                                                                  |
| 12  | CloudFront distribution              | Default behaviour goes to S3 through origin access control; `/api/*` and `/grafana/*` go to the EC2 origin over HTTP on 80; caching disabled for `/api/*`           |
| 13  | GitHub OIDC provider and deploy role | Trusted by the four repos' `main` branch; pushes to ECR, syncs S3, invalidates CloudFront, runs SSM `SendCommand` on the instance tagged `project=feedwatch`        |

The instance runs [`compose.aws.yaml`](../compose.aws.yaml). An nginx container on port 80 routes `/api/*` to the API and `/grafana/*` to Grafana, and serves nothing else.

## Order

1. Run `00-preflight.py` (read-only). Its 2026-11-17 run found every needed read allowed and no Feedwatch resources.
2. Run 01 to 09 in order, one at a time, checking each result.
3. Build and push images from CI (`deploy.yml` in each Rust repo), or by hand with `docker buildx --platform linux/arm64`.
4. Start the stack: SSM `SendCommand` runs `docker compose -f compose.aws.yaml pull && up -d`.
5. Add the DNS records in Namecheap: the ACM validation CNAME, then `feedwatch` as a CNAME to the CloudFront domain.
6. Prove it: the site loads; `/api/health` is ok; breaking every RPC parameter fires the alarm (FR-FW-9); restoring them clears it.

## Cost estimate (to confirm before M4)

A t4g.small, 20 GB of gp3, the Elastic IP's IPv4 charge, CloudWatch Logs at low volume, and CloudFront and S3 within or near the free tier. The expected total is roughly $15–20 a month. Confirm with current prices before creating anything.

## Local equivalent

`docker compose up -d` in this repo runs InfluxDB and Grafana. The poller and API run with `cargo run` from their own repos, using `.env` files copied from `.env.example`.

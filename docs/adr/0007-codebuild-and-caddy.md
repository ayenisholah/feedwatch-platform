# 0007: CodeBuild for builds, Caddy on the host until CloudFront is available

**Status:** Accepted, 2026-11-17. Amends [0006](0006-single-ec2-host.md).

## Context

Two restrictions came up during the first deployment, through the AWS MCP on 2026-11-17:

- The organisation's service control policy explicitly denies `iam:CreateOpenIDConnectProvider`, and reading OIDC providers. GitHub Actions therefore can't assume a role in this account. Creating an IAM user with long-lived access keys for GitHub would work around a deliberate guardrail, so it's ruled out.
- `cloudfront:CreateDistribution` returned "Your account must be verified before you can add new CloudFront resources". Only the owner can request that, through an AWS Support case.

## Decision

- **Builds run in AWS CodeBuild** (project `feedwatch-build`, arm64, privileged). It clones the public repo at a ref, builds an image and pushes it to ECR, or builds the web client's static export and syncs it to S3. Builds are started through the AWS MCP (`codebuild:StartBuild`), and deploys go through SSM Run Command, which runs `scripts/aws/deploy.sh` on the host. GitHub Actions keeps running CI only.
- **Caddy on the EC2 host serves everything** for now: the web client (synced from S3 to the host), `/api/*` and `/grafana/*`. Caddy obtains and renews a Let's Encrypt certificate on its own once a domain points at the Elastic IP; until then the site is plain HTTP on the IP. The security group allows ports 80 and 443 from anywhere, with no SSH.
- The CloudFront origin access control (`feedwatch-web`) and function (`feedwatch-index`) are already created and cost nothing unused. When the account is verified, a distribution can sit in front of the host and bucket without changing the build.

## Consequences

- Deploys need the AWS MCP or AWS CLI access; a merge to `main` doesn't deploy by itself.
- No CDN: every request reaches the single host. That's acceptable for a portfolio-scale monitor.
- HTTPS depends on the owner adding an A record in Namecheap and setting `/feedwatch/site/address` to the domain.

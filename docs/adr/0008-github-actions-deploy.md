# 0008: GitHub Actions deploys every merge to main, through a scoped IAM user

**Status:** Accepted, 2026-11-18. Supersedes the "deploys only through the AWS MCP" part of [0007](0007-codebuild-and-caddy.md).

## Context

The owner wants every merge to `main` deployed to production by GitHub Actions. The usual keyless route, a GitHub OIDC provider and a role, is denied by the organisation's SCP (F-19). ADR 0007 ruled out an IAM user with long-lived keys as a way around that guardrail. The owner controls the organisation and accepted the trade-off on 2026-11-18, on condition that the key can do as little as possible.

Deploying by hand had also caused a real outage. On 2026-11-17 the FR-FW-9 failure test left a dead RPC URL in the host's `.env`. Every poll failed for about 11 hours, until the next deploy rewrote `.env` from SSM. A deploy on every merge, with a smoke check, makes that kind of drift short-lived and visible.

## Decision

- **SSM document `feedwatch-deploy`:** takes no parameters. It runs `git pull` in `/opt/feedwatch/platform`, then `flock /opt/feedwatch/deploy.lock bash scripts/aws/deploy.sh`.
  - Pulling before running means a change to `deploy.sh` takes effect in the same deploy. Bash runs a script from the file it opened, so `deploy.sh` pulling itself ran the old copy, which bit us on 2026-11-18.
  - The lock queues deploys started by merges in different repos.
- **IAM user `feedwatch-deployer`** (path `/feedwatch/`), with one inline policy, `feedwatch-deploy-only`:
  - `ssm:SendCommand` for that document only, on instances tagged `project=feedwatch` only;
  - `ssm:ListCommandInvocations` and `ssm:GetCommandInvocation` to follow the run;
  - `ssm:GetParameter` on `/feedwatch/site/url` for the smoke check.
  - The policy simulator, given `aws:RequestedRegion`, denies everything else: `AWS-RunShellScript`, sessions, other parameters and IAM.
  - Its key is stored as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` repository secrets by `scripts/aws/set-deploy-secrets.sh`, and never passes through a chat or a file.
- **The `Deploy` workflow** lives in this repo (`.github/workflows/deploy.yml`).
  - It runs after `CI` succeeds for a push to `main`, or by hand. The poller, API and web repos call it as a reusable workflow on the same trigger.
  - It sends the document, waits, prints the host's output, fails on any status but `Success`, and then checks `/api/health` and `/` on the site URL.
- In `host` build mode every deploy rebuilds all services from `main`, about 4 to 5 minutes. When CodeBuild becomes available (ADR 0007), the same workflow can start a build first.

## Consequences

- A merge to `main` in any repo is in production about 5 minutes after CI passes, and the Actions run shows the result.
- A leaked key could only start a redeploy of what's already on `main`. It can't run commands, read secrets or change AWS. Rotate it yearly with `ROTATE=1 scripts/aws/set-deploy-secrets.sh`, and delete the user if the account moves to OIDC.
- Only commits whose `CI` run passed are deployed, so a failing push to `main` never reaches production. GitHub branch protection isn't enabled on `main` yet; only the local pre-push hook stops direct pushes.

# AWS scripts

| File                | Runs where                          | Does                                                                              |
| ------------------- | ----------------------------------- | --------------------------------------------------------------------------------- |
| `00-preflight.py`   | AWS MCP `aws___run_script`          | Read-only: caller, Region, service reads, existing Feedwatch resources            |
| `host-bootstrap.sh` | EC2 user data                       | Installs Docker and Compose, adds swap, clones this repo, runs `deploy.sh`        |
| `deploy.sh`         | The host, through SSM Run Command   | Writes `.env` from SSM, syncs the site, pulls images, runs `compose.aws.yaml`     |
| `buildspec.yml`     | CodeBuild project `feedwatch-build` | Builds `TARGET` (`poller`, `api` or `web`) at `REF` and publishes it to ECR or S3 |

The resource-creation steps were run through the AWS MCP on 2026-11-17. [Deployment](../../docs/DEPLOYMENT.md) lists every resource and the order, and each step looks its resource up by name or tag before creating it.

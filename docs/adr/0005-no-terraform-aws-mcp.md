# 0005: No Terraform; create AWS resources through the AWS MCP

**Status:** Accepted, 2026-11-16.

## Context

Terraform describes infrastructure in code and tracks it in a state file. It pays off with many resources, several environments or a team reviewing infrastructure changes. Feedwatch has about a dozen resources, one environment and one owner. The owner judged Terraform overkill and asked for deployment through the AWS MCP.

## Decision

Create and change resources with idempotent boto3 snippets in `scripts/aws/`, run through the AWS MCP's `run_script`. Each snippet finds its resource by name or by the tag `project=feedwatch` before creating it, and a teardown snippet removes everything with that tag.

## Consequences

- No state file to store or lock.
- Drift isn't detected automatically. `00-preflight.py` lists the Feedwatch resources each service holds, so a review can compare them with [deployment](../DEPLOYMENT.md).
- If the project grows to several environments, reconsider infrastructure as code.

# AWS snippets

Python snippets run through the AWS MCP tool `aws___run_script`. That tool provides `call_boto3`, and each script ends with `result = {...}` followed by a bare `result`. See [deployment](../../docs/DEPLOYMENT.md) for the rules and order.

| File                   | Does                                                                                      | Status                  |
| ---------------------- | ----------------------------------------------------------------------------------------- | ----------------------- |
| `00-preflight.py`      | Read-only: caller, Region, service reads, and existing Feedwatch resources by name or tag | Written, run 2026-11-17 |
| `01-budget.py`         | AWS Budgets, $25/month                                                                    | M4                      |
| `02-ecr.py`            | ECR repos and lifecycle policy                                                            | M4                      |
| `03-ssm-parameters.py` | Parameter names only. You set the values.                                                 | M4                      |
| `04-iam.py`            | Instance role and profile; GitHub OIDC provider and deploy role                           | M4                      |
| `05-network.py`        | Security group (CloudFront prefix list, port 80) and Elastic IP                           | M4                      |
| `06-ec2.py`            | Instance and user data                                                                    | M4                      |
| `07-cloudwatch.py`     | Log groups, SNS topic, alarms                                                             | M4                      |
| `08-s3-cloudfront.py`  | Bucket, origin access control, certificate lookup, distribution                           | M4                      |
| `90-teardown.py`       | Delete everything tagged `project=feedwatch`                                              | M4                      |

Each create snippet looks for its resource by name or tag first (per service: the account denies `tag:GetResources`), and returns `{"created": false, ...}` when it already exists.

# Read-only preflight for Feedwatch on AWS. Run through the AWS MCP `aws___run_script`.
# Creates nothing. Reports the caller (without the account ID), whether the services M4 needs
# are readable, and any Feedwatch resources that already exist. The account's policy denies
# iam:ListAccountAliases and tag:GetResources, so resources are found per service by name or tag.

REGION = "eu-north-1"  # the only Region the account's service control policy allows (checked 2026-11-17)
CERT_REGION = "us-east-1"  # CloudFront certificates must be in us-east-1


def _status(result):
    if isinstance(result, Exception):
        return "denied" if "not authorized" in str(result) or "AccessDenied" in str(result) else str(result)[:120]
    return "ok"


async def preflight():
    identity, offerings, ecr, params, logs, distributions, certs, instances = await asyncio.gather(
        call_boto3(service_name="sts", operation_name="GetCallerIdentity"),
        call_boto3(service_name="ec2", operation_name="DescribeInstanceTypeOfferings", region_name=REGION,
                   params={"Filters": [{"Name": "instance-type", "Values": ["t4g.small"]}]}),
        call_boto3(service_name="ecr", operation_name="DescribeRepositories", region_name=REGION),
        call_boto3(service_name="ssm", operation_name="DescribeParameters", region_name=REGION,
                   params={"ParameterFilters": [{"Key": "Path", "Option": "Recursive", "Values": ["/feedwatch"]}]}),
        call_boto3(service_name="logs", operation_name="DescribeLogGroups", region_name=REGION,
                   params={"logGroupNamePrefix": "/feedwatch/"}),
        call_boto3(service_name="cloudfront", operation_name="ListDistributions"),
        call_boto3(service_name="acm", operation_name="ListCertificates", region_name=CERT_REGION),
        call_boto3(service_name="ec2", operation_name="DescribeInstances", region_name=REGION,
                   params={"Filters": [{"Name": "tag:project", "Values": ["feedwatch"]}]}),
        return_exceptions=True,
    )
    ok = lambda r: not isinstance(r, Exception)  # noqa: E731
    dist_items = (distributions.get("DistributionList") or {}).get("Items", []) if ok(distributions) else []
    return {
        "principal": identity["Arn"].split(":")[-1] if ok(identity) else _status(identity),
        "region": REGION,
        "t4g_small_offered": bool(offerings.get("InstanceTypeOfferings")) if ok(offerings) else _status(offerings),
        "reads": {name: _status(r) for name, r in
                  [("ecr", ecr), ("ssm", params), ("logs", logs), ("cloudfront", distributions), ("acm", certs), ("ec2", instances)]},
        "existing": {
            "ecr_repos": [r["repositoryName"] for r in ecr.get("repositories", []) if r["repositoryName"].startswith("feedwatch")] if ok(ecr) else None,
            "ssm_parameters": [p["Name"] for p in params.get("Parameters", [])] if ok(params) else None,
            "log_groups": [g["logGroupName"] for g in logs.get("logGroups", [])] if ok(logs) else None,
            "instances": [i["InstanceId"] for res in instances.get("Reservations", []) for i in res["Instances"]] if ok(instances) else None,
            "distributions_for_feedwatch": [d["Id"] for d in dist_items if "feedwatch" in str(d.get("Aliases", {}))],
            "certificates_for_feedwatch": [c["DomainName"] for c in certs.get("CertificateSummaryList", []) if "feedwatch" in c["DomainName"]] if ok(certs) else None,
        },
    }


result = await preflight()
result

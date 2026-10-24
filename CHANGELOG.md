# Changelog

## 1.0.2

### Tests

- Removed `test_flow_log_role_scoped`: it only compared `var.flow_log_retention_days` with the value the test had just set, and the flow-log log group and IAM policy are owned by the upstream child module, so no root resource or output exposes them. The scoped role and retention are covered by `trivy config` and the nightly `tests/complete.tftest.hcl` apply.

### Docs

- README Usage shows the naming module.

## 1.0.1

### Fixes

- render declared provider constraints and skip .terraform in trivy scans
- declare required_version and providers in examples/minimal

## 1.0.0

- Initial release: VPC with computed public and private subnets across 2-3 availability zones, NAT strategy (none, single, per_az), DNS support and hostnames, and CloudWatch flow logs with an IAM policy scoped to the log group.

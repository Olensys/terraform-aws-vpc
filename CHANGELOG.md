# Changelog

## [1.0.4](https://github.com/Olensys/terraform-aws-vpc/compare/v1.0.3...v1.0.4) (2026-10-24)


### Bug Fixes

* **examples:** unique application slug so concurrent integration runs do not collide ([#2](https://github.com/Olensys/terraform-aws-vpc/issues/2)) ([704525c](https://github.com/Olensys/terraform-aws-vpc/commit/704525c9279b48af01db08d738f12b1cdc4fa0a4))

## [1.0.3](https://github.com/Olensys/terraform-aws-vpc/compare/v1.0.2...v1.0.3) (2026-10-24)


### Bug Fixes

* **examples:** pin naming module to v1.0.1 ([e757230](https://github.com/Olensys/terraform-aws-vpc/commit/e75723087c35c9e64ca1fab91f1ccab189c9ec85))
* run integration on change and weekly instead of nightly ([b6920c6](https://github.com/Olensys/terraform-aws-vpc/commit/b6920c68f5bfe7543bb9ceaf0b9fa61934069412))

## 1.0.2

### Tests

- Removed `test_flow_log_role_scoped`: it only compared `var.flow_log_retention_days` with the value the test had just set, and the flow-log log group and IAM policy are owned by the upstream child module, so no root resource or output exposes them. The scoped role and retention are only truly checked by a real apply (the nightly `tests/complete.tftest.hcl` applies the example but asserts nothing about them); `trivy config` enforces them statically where applicable.

### Docs

- README Usage shows the naming module.

## 1.0.1

### Fixes

- render declared provider constraints and skip .terraform in trivy scans
- declare required_version and providers in examples/minimal

## 1.0.0

- Initial release: VPC with computed public and private subnets across 2-3 availability zones, NAT strategy (none, single, per_az), DNS support and hostnames, and CloudWatch flow logs with an IAM policy scoped to the log group.

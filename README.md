# terraform-aws-vpc

VPC with public and private subnets across AZs, NAT strategy (gateway or instance), DNS and least-privilege flow logs

## Opinions

- Public and private subnet tiers only, one of each per availability zone (`az_count` 2 or 3). No database tier.
- Subnets are computed with `cidrsubnets`, each the VPC CIDR plus 4 bits (a /16 yields /20 subnets): the first `az_count` blocks are public, the next `az_count` are private.
- `public_subnet_cidrs` and `private_subnet_cidrs` replace the computed subnet blocks (one CIDR per availability zone); use them to adopt an existing VPC without replacing its subnets.
- NAT strategy `nat`: `none`, `single` (default, one shared gateway), `per_az` or `instance` (one NAT instance with a static Elastic IP, see below).
- DNS support and DNS hostnames are always on.
- Public subnets do not auto-assign public IPs (`map_public_ip_on_launch = false`).
- Flow logs (default on) go to a CloudWatch log group created by the upstream module, with the retention set by `flow_log_retention_days` (default 30). The upstream IAM role policy is limited to that log group's ARN, never `*`.
- Tags are `context.extra_tags` merged with `tags`, with `tags` applied last.

## Usage

```hcl
module "naming" {
  source  = "git::https://github.com/Olensys/terraform-null-naming.git?ref=v1.0.1"
  context = var.context
}

module "vpc" {
  source  = "git::https://github.com/Olensys/terraform-aws-vpc.git?ref=v1.1.0"
  name    = module.naming.name
  context = var.context

  cidr = "10.0.0.0/16"

  tags = module.naming.tags
}
```

## NAT instance

`nat = "instance"` uses one `t4g.nano` instance instead of a managed NAT gateway (Amazon Linux 2023, arm64, AMI resolved from the `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64` public SSM parameter) in the first public subnet, holding an Elastic IP. It is a good fit for dev and test VPCs, or for any workload whose egress must come from one static IP and does not need the throughput or multi-AZ resilience of a gateway: the instance costs a few dollars a month instead of a gateway's hourly plus per-gigabyte charges, and the Elastic IP never changes.

What the module creates in this mode, all carrying the module tags:

- `aws_eip` (`domain = "vpc"`) with `prevent_destroy = true`: the IP is typically allow-listed by third parties, so the module never releases it. To retire it, remove it from state (`terraform state rm`) or delete the lifecycle block first.
- `aws_instance` with `source_dest_check = false`, IMDSv2 required, termination protection and an encrypted root volume, plus `aws_eip_association`. The AMI, the user data and the root block device are in `ignore_changes`, so neither a new Amazon Linux release nor an imported instance's own bootstrap or unencrypted root volume re-creates a working instance.
- A security group allowing all traffic from the VPC CIDR and all egress.
- An IAM role and instance profile with `AmazonSSMManagedInstanceCore` for Session Manager access (no SSH, no key pair).
- A `0.0.0.0/0` route to the instance's network interface in every private route table. The upstream module still creates a single private route table in this mode.

The user data creates a 1 GB swap file (package installation is OOM-killed on 512 MB without it), installs `iptables-services`, enables `net.ipv4.ip_forward`, masquerades the VPC CIDR on the default interface and saves the rules so they survive a reboot.

Trade-offs: a single instance in a single AZ, so losing the instance or its zone takes private egress down until it is replaced, and throughput is bound by the instance's network allowance. Use `single` or `per_az` where that matters.

`nat_public_ips` returns the instance's Elastic IP, so consumers reading it keep working across strategies. `nat_instance_id` and `nat_instance_security_group_id` expose the instance and its security group.

### Importing an existing NAT instance

If private subnets already route through a hand-built NAT instance, import the Elastic IP, the instance and the default route instead of creating new ones, so the static IP is kept. With the module called `vpc`:

```bash
terraform import 'module.vpc.aws_eip.nat_instance[0]' eipalloc-0123456789abcdef0
terraform import 'module.vpc.aws_instance.nat_instance[0]' i-0123456789abcdef0
terraform import 'module.vpc.aws_eip_association.nat_instance[0]' eipassoc-0123456789abcdef0
terraform import 'module.vpc.aws_route.nat_instance["0"]' rtb-0123456789abcdef0_0.0.0.0/0
terraform import 'module.vpc.aws_security_group.nat_instance[0]' sg-0123456789abcdef0
terraform import 'module.vpc.aws_vpc_security_group_ingress_rule.nat_instance_vpc[0]' sgr-0123456789abcdef0
terraform import 'module.vpc.aws_vpc_security_group_egress_rule.nat_instance_all[0]' sgr-0123456789abcdef1
terraform import 'module.vpc.aws_iam_role.nat_instance[0]' my-vpc-nat-instance
terraform import 'module.vpc.aws_iam_instance_profile.nat_instance[0]' my-vpc-nat-instance
terraform import 'module.vpc.aws_iam_role_policy_attachment.nat_instance_ssm[0]' my-vpc-nat-instance/arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```

The route key is the position of the route table in `private_route_table_ids` (`"0"` with a single private route table). Resources the module creates alongside (security group `<name>-nat-instance`, IAM role and instance profile `<name>-nat-instance`) can be imported the same way; names and the security group description are immutable, so an existing one with a different name is replaced instead. After importing, `terraform plan` updates the instance's security group, instance profile, metadata options and tags in place; it does not replace the instance. The plan shows a replacement only when the existing instance differs in something immutable: a different subnet or no public IP association.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0, < 7.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_this"></a> [this](#module\_this) | terraform-aws-modules/vpc/aws | 6.7.3 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_eip.nat_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip_association.nat_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip_association) | resource |
| [aws_iam_instance_profile.nat_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.nat_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.nat_instance_ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.nat_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_route.nat_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_security_group.nat_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.nat_instance_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.nat_instance_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_iam_policy_document.nat_instance_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_ssm_parameter.nat_instance_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cidr"></a> [cidr](#input\_cidr) | IPv4 CIDR block of the VPC. Must be a /24 or larger so each subnet can be a /28 or larger. | `string` | n/a | yes |
| <a name="input_context"></a> [context](#input\_context) | Deployment context used for naming, tagging and environment-dependent defaults. | <pre>object({<br/>    organization = string<br/>    environment  = string<br/>    application  = string<br/>    component    = optional(string)<br/>    owner        = string<br/>    cost_center  = string<br/>    extra_tags   = optional(map(string), {})<br/>  })</pre> | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Resource name. Lowercase letters, digits and hyphens. | `string` | n/a | yes |
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Number of availability zones to span. One public and one private subnet is created per zone. | `number` | `2` | no |
| <a name="input_create"></a> [create](#input\_create) | Whether to create any resources. Set false to create nothing. | `bool` | `true` | no |
| <a name="input_enable_flow_logs"></a> [enable\_flow\_logs](#input\_enable\_flow\_logs) | Whether to send VPC flow logs to a CloudWatch log group owned by this module. | `bool` | `true` | no |
| <a name="input_flow_log_retention_days"></a> [flow\_log\_retention\_days](#input\_flow\_log\_retention\_days) | Retention in days of the flow log CloudWatch log group. | `number` | `30` | no |
| <a name="input_nat"></a> [nat](#input\_nat) | NAT strategy for private subnet egress: none (no NAT), single (one shared NAT gateway), per\_az (one NAT gateway per availability zone), instance (one t4g.nano NAT instance with a static Elastic IP in the first public subnet; cheaper than a gateway, single AZ, no HA). | `string` | `"single"` | no |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | Explicit CIDR blocks of the private subnets, one per availability zone (the list length must equal az\_count), instead of the computed ones. Null computes them from cidr. | `list(string)` | `null` | no |
| <a name="input_private_subnet_tags"></a> [private\_subnet\_tags](#input\_private\_subnet\_tags) | Extra tags for private subnets, e.g. kubernetes.io/role/internal-elb for internal load balancer discovery. | `map(string)` | `{}` | no |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | Explicit CIDR blocks of the public subnets, one per availability zone (the list length must equal az\_count), instead of the computed ones. Use it to adopt an existing VPC without replacing its subnets. Null computes them from cidr. | `list(string)` | `null` | no |
| <a name="input_public_subnet_tags"></a> [public\_subnet\_tags](#input\_public\_subnet\_tags) | Extra tags for public subnets, e.g. kubernetes.io/role/elb for load balancer discovery. | `map(string)` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags merged onto every taggable resource, applied last. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the VPC. Null when create is false. |
| <a name="output_azs"></a> [azs](#output\_azs) | Availability zones the VPC spans. Null when create is false. |
| <a name="output_cidr"></a> [cidr](#output\_cidr) | IPv4 CIDR block of the VPC. Null when create is false. |
| <a name="output_id"></a> [id](#output\_id) | ID of the VPC. Null when create is false. |
| <a name="output_name"></a> [name](#output\_name) | Name of the VPC. Null when create is false. |
| <a name="output_nat_instance_id"></a> [nat\_instance\_id](#output\_nat\_instance\_id) | ID of the NAT instance when nat is instance, otherwise null. Null when create is false. |
| <a name="output_nat_instance_security_group_id"></a> [nat\_instance\_security\_group\_id](#output\_nat\_instance\_security\_group\_id) | ID of the NAT instance's security group when nat is instance, otherwise null. Null when create is false. |
| <a name="output_nat_public_ips"></a> [nat\_public\_ips](#output\_nat\_public\_ips) | Public IPs of the NAT gateways, or the NAT instance's Elastic IP when nat is instance (empty when nat is none). Null when create is false. |
| <a name="output_nat_strategy"></a> [nat\_strategy](#output\_nat\_strategy) | Resolved NAT strategy flags: enabled (private subnets have internet egress), single, per\_az, instance. Null when create is false. |
| <a name="output_private_route_table_ids"></a> [private\_route\_table\_ids](#output\_private\_route\_table\_ids) | IDs of the private route tables. Null when create is false. |
| <a name="output_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#output\_private\_subnet\_cidrs) | CIDR blocks of the private subnets, in availability zone order. Null when create is false. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | IDs of the private subnets, one per availability zone. Null when create is false. |
| <a name="output_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#output\_public\_subnet\_cidrs) | CIDR blocks of the public subnets, in availability zone order. Null when create is false. |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | IDs of the public subnets, one per availability zone. Null when create is false. |
| <a name="output_tags"></a> [tags](#output\_tags) | Tags applied to every taggable resource, with context.extra\_tags merged in. Null when create is false. |
<!-- END_TF_DOCS -->

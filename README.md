# terraform-aws-vpc

VPC with public and private subnets across AZs, NAT gateway strategy, DNS and least-privilege flow logs

## Opinions

- Public and private subnet tiers only, one of each per availability zone (`az_count` 2 or 3). No database tier.
- Subnets are computed with `cidrsubnets`, each the VPC CIDR plus 4 bits (a /16 yields /20 subnets): the first `az_count` blocks are public, the next `az_count` are private.
- NAT strategy `nat`: `none`, `single` (default, one shared gateway) or `per_az`. No NAT instances.
- DNS support and DNS hostnames are always on.
- Public subnets do not auto-assign public IPs (`map_public_ip_on_launch = false`).
- Flow logs (default on) go to a CloudWatch log group created by the upstream module, with the retention set by `flow_log_retention_days` (default 30). The upstream IAM role policy is limited to that log group's ARN, never `*`.
- Tags are `context.extra_tags` merged with `tags`, with `tags` applied last.

## Usage

```hcl
module "this" {
  source = "git::https://github.com/Olensys/terraform-aws-vpc.git?ref=v1.0.0"

  name = "example"
  context = {
    organization = "olensys"
    environment  = "dev"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }
  cidr = "10.0.0.0/16"
}
```

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
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

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
| <a name="input_nat"></a> [nat](#input\_nat) | NAT gateway strategy: none (no NAT), single (one shared NAT gateway), per\_az (one NAT gateway per availability zone). | `string` | `"single"` | no |
| <a name="input_private_subnet_tags"></a> [private\_subnet\_tags](#input\_private\_subnet\_tags) | Extra tags for private subnets, e.g. kubernetes.io/role/internal-elb for internal load balancer discovery. | `map(string)` | `{}` | no |
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
| <a name="output_nat_public_ips"></a> [nat\_public\_ips](#output\_nat\_public\_ips) | Public IPs of the NAT gateways (empty when nat is none). Null when create is false. |
| <a name="output_nat_strategy"></a> [nat\_strategy](#output\_nat\_strategy) | Resolved NAT strategy flags (enabled, single, per\_az) passed to the upstream module. Null when create is false. |
| <a name="output_private_route_table_ids"></a> [private\_route\_table\_ids](#output\_private\_route\_table\_ids) | IDs of the private route tables. Null when create is false. |
| <a name="output_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#output\_private\_subnet\_cidrs) | CIDR blocks of the private subnets, in availability zone order. Null when create is false. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | IDs of the private subnets, one per availability zone. Null when create is false. |
| <a name="output_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#output\_public\_subnet\_cidrs) | CIDR blocks of the public subnets, in availability zone order. Null when create is false. |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | IDs of the public subnets, one per availability zone. Null when create is false. |
| <a name="output_tags"></a> [tags](#output\_tags) | Tags applied to every taggable resource, with context.extra\_tags merged in. Null when create is false. |
<!-- END_TF_DOCS -->

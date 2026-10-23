data "aws_availability_zones" "available" {
  count = var.create ? 1 : 0

  state = "available"
}

locals {
  tags = merge(var.context.extra_tags, var.tags)

  azs = var.create ? slice(data.aws_availability_zones.available[0].names, 0, var.az_count) : []

  # First az_count blocks are public, the next az_count are private; every block is the VPC CIDR plus 4 bits.
  subnet_cidrs         = cidrsubnets(var.cidr, [for _ in range(2 * var.az_count) : 4]...)
  public_subnet_cidrs  = slice(local.subnet_cidrs, 0, var.az_count)
  private_subnet_cidrs = slice(local.subnet_cidrs, var.az_count, 2 * var.az_count)

  nat_strategy = {
    enabled = var.nat != "none"
    single  = var.nat == "single"
    per_az  = var.nat == "per_az"
  }
}

module "this" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  create_vpc = var.create
  name       = var.name
  cidr       = var.cidr

  azs             = local.azs
  public_subnets  = local.public_subnet_cidrs
  private_subnets = local.private_subnet_cidrs

  enable_nat_gateway     = local.nat_strategy.enabled
  single_nat_gateway     = local.nat_strategy.single
  one_nat_gateway_per_az = local.nat_strategy.per_az

  enable_dns_hostnames = true
  enable_dns_support   = true

  # ALBs do not need auto-assigned public IPs; tasks request one explicitly when required.
  map_public_ip_on_launch = false

  enable_flow_log                                 = var.enable_flow_logs
  create_flow_log_cloudwatch_log_group            = var.enable_flow_logs
  create_flow_log_cloudwatch_iam_role             = var.enable_flow_logs
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_log_retention_days

  public_subnet_tags  = var.public_subnet_tags
  private_subnet_tags = var.private_subnet_tags

  tags = local.tags
}

data "aws_availability_zones" "available" {
  count = var.create ? 1 : 0

  state = "available"
}

locals {
  tags = merge(var.context.extra_tags, var.tags)

  azs = var.create ? slice(data.aws_availability_zones.available[0].names, 0, var.az_count) : []

  # First az_count blocks are public, the next az_count are private; every block is the VPC CIDR plus 4 bits.
  subnet_cidrs         = cidrsubnets(var.cidr, [for _ in range(2 * var.az_count) : 4]...)
  public_subnet_cidrs  = coalesce(var.public_subnet_cidrs, slice(local.subnet_cidrs, 0, var.az_count))
  private_subnet_cidrs = coalesce(var.private_subnet_cidrs, slice(local.subnet_cidrs, var.az_count, 2 * var.az_count))

  # enabled: private subnets get a default route to the internet (through a gateway or the instance).
  nat_strategy = {
    enabled  = var.nat != "none"
    single   = var.nat == "single"
    per_az   = var.nat == "per_az"
    instance = var.nat == "instance"
  }

  # In instance mode the upstream module creates no gateway, but single_nat_gateway stays true so it
  # still creates ONE private route table; with both flags false it creates one per AZ instead.
  upstream_nat = {
    enable_nat_gateway     = local.nat_strategy.single || local.nat_strategy.per_az
    single_nat_gateway     = local.nat_strategy.single || local.nat_strategy.instance
    one_nat_gateway_per_az = local.nat_strategy.per_az
  }

  create_nat_instance    = var.create && local.nat_strategy.instance
  nat_instance_name      = "${var.name}-nat-instance"
  nat_instance_role_name = "${substr(var.name, 0, 51)}-nat-instance" # IAM names are capped at 64 characters
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

  enable_nat_gateway     = local.upstream_nat.enable_nat_gateway
  single_nat_gateway     = local.upstream_nat.single_nat_gateway
  one_nat_gateway_per_az = local.upstream_nat.one_nat_gateway_per_az

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

# ---------------------------------------------------------------------------------------------------
# NAT instance (nat = "instance"): one t4g.nano in the first public subnet with a static Elastic IP,
# routing 0.0.0.0/0 for every private route table. Cheaper than a managed gateway; single AZ, no HA.
# ---------------------------------------------------------------------------------------------------

data "aws_partition" "current" {
  count = local.create_nat_instance ? 1 : 0
}

data "aws_ssm_parameter" "nat_instance_ami" {
  count = local.create_nat_instance ? 1 : 0

  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_iam_policy_document" "nat_instance_assume" {
  count = local.create_nat_instance ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nat_instance" {
  count = local.create_nat_instance ? 1 : 0

  name               = local.nat_instance_role_name
  assume_role_policy = data.aws_iam_policy_document.nat_instance_assume[0].json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "nat_instance_ssm" {
  count = local.create_nat_instance ? 1 : 0

  role       = aws_iam_role.nat_instance[0].name
  policy_arn = "arn:${data.aws_partition.current[0].partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nat_instance" {
  count = local.create_nat_instance ? 1 : 0

  name = local.nat_instance_role_name
  role = aws_iam_role.nat_instance[0].name

  tags = local.tags
}

resource "aws_security_group" "nat_instance" {
  count = local.create_nat_instance ? 1 : 0

  name        = local.nat_instance_name
  description = "NAT instance: forwards private-subnet egress"
  vpc_id      = module.this.vpc_id

  tags = merge(local.tags, { Name = local.nat_instance_name })
}

resource "aws_vpc_security_group_ingress_rule" "nat_instance_vpc" {
  count = local.create_nat_instance ? 1 : 0

  security_group_id = aws_security_group.nat_instance[0].id
  description       = "All traffic from the VPC"
  ip_protocol       = "-1"
  cidr_ipv4         = var.cidr

  tags = merge(local.tags, { Name = "${local.nat_instance_name}-vpc" })
}

#trivy:ignore:AVD-AWS-0104 a NAT instance forwards the private subnets' traffic to the internet by design
resource "aws_vpc_security_group_egress_rule" "nat_instance_all" {
  count = local.create_nat_instance ? 1 : 0

  security_group_id = aws_security_group.nat_instance[0].id
  description       = "All egress"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(local.tags, { Name = "${local.nat_instance_name}-egress" })
}

# The Elastic IP is the VPC's static egress address and is typically allow-listed by third parties,
# so it is never destroyed by this module: remove it from state or the ignore block first.
resource "aws_eip" "nat_instance" {
  count = local.create_nat_instance ? 1 : 0

  domain = "vpc"

  tags = merge(local.tags, { Name = local.nat_instance_name })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_instance" "nat_instance" {
  count = local.create_nat_instance ? 1 : 0

  ami           = data.aws_ssm_parameter.nat_instance_ami[0].value
  instance_type = "t4g.nano"
  subnet_id     = module.this.public_subnets[0]

  # The subnet does not auto-assign public IPs; the instance needs one at first boot to install
  # packages before the Elastic IP is associated. An instance holding an EIP reads back as true.
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.nat_instance[0].id]
  iam_instance_profile        = aws_iam_instance_profile.nat_instance[0].name
  source_dest_check           = false
  disable_api_termination     = true
  user_data                   = templatefile("${path.module}/templates/nat-instance-user-data.sh.tftpl", { vpc_cidr = var.cidr })

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = merge(local.tags, { Name = local.nat_instance_name })

  # The AMI parameter moves with every Amazon Linux release, imported instances have their own user
  # data and root volume (often unencrypted, which would otherwise force a replacement); none of these
  # must replace a working NAT instance. New instances still get an encrypted root volume.
  lifecycle {
    ignore_changes = [ami, user_data, root_block_device]
  }
}

resource "aws_eip_association" "nat_instance" {
  count = local.create_nat_instance ? 1 : 0

  allocation_id = aws_eip.nat_instance[0].id
  instance_id   = aws_instance.nat_instance[0].id
}

# Keyed by position so the keys are known at plan time (the route table IDs are not). With
# single_nat_gateway the upstream module creates one private route table; the for_each covers any number.
resource "aws_route" "nat_instance" {
  for_each = { for i, id in(local.create_nat_instance ? module.this.private_route_table_ids : []) : tostring(i) => id }

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance[0].primary_network_interface_id
}

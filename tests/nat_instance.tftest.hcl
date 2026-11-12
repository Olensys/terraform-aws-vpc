# nat = "instance": the module owns the NAT instance, its Elastic IP and the private default routes.
# Plan only: the Elastic IP has prevent_destroy, which would fail the apply-mode cleanup.
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names    = ["us-east-1a", "us-east-1b", "us-east-1c"]
      zone_ids = ["use1-az1", "use1-az2", "use1-az3"]
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }

  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }

  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/mock" }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:mock" }
  }

  mock_resource "aws_vpc" {
    defaults = { arn = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-0123456789abcdef0" }
  }
}

variables {
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
    extra_tags   = { Project = "example" }
  }
  name = "example"
  cidr = "10.0.0.0/16"
  nat  = "instance"
  tags = { Environment = "test", Application = "example" }
}

run "test_instance_strategy_flags" {
  command = plan

  assert {
    condition     = output.nat_strategy == { enabled = true, single = false, per_az = false, instance = true }
    error_message = "nat instance must resolve to the instance strategy with egress enabled."
  }

  assert {
    condition     = length(output.private_route_table_ids) == 1
    error_message = "Instance mode must keep a single private route table (upstream single_nat_gateway stays true)."
  }
}

run "test_instance_resources" {
  command = plan

  assert {
    condition     = length(aws_instance.nat_instance) == 1 && length(aws_eip.nat_instance) == 1 && length(aws_eip_association.nat_instance) == 1
    error_message = "Instance mode must create exactly one instance, one Elastic IP and one association."
  }

  assert {
    condition     = aws_instance.nat_instance[0].instance_type == "t4g.nano" && aws_instance.nat_instance[0].source_dest_check == false && aws_instance.nat_instance[0].disable_api_termination == true
    error_message = "NAT instance must be a t4g.nano with source/destination checks off and termination protection on."
  }

  assert {
    condition     = aws_instance.nat_instance[0].metadata_options[0].http_tokens == "required"
    error_message = "NAT instance must require IMDSv2."
  }

  assert {
    condition     = aws_security_group.nat_instance[0].name == "example-nat-instance" && aws_iam_role.nat_instance[0].name == "example-nat-instance" && aws_iam_instance_profile.nat_instance[0].name == "example-nat-instance" && aws_instance.nat_instance[0].tags.Name == "example-nat-instance"
    error_message = "The instance, security group, role and profile must be named <name>-nat-instance."
  }

  assert {
    condition     = aws_instance.nat_instance[0].ami == "ami-0123456789abcdef0"
    error_message = "NAT instance AMI must come from the AL2023 arm64 SSM public parameter."
  }

  assert {
    condition     = can(regex("iptables -t nat -A POSTROUTING -o \"\\$default_iface\" -s 10.0.0.0/16 -j MASQUERADE", aws_instance.nat_instance[0].user_data))
    error_message = "User data must masquerade the VPC CIDR on the default interface."
  }

  assert {
    condition     = can(regex("mkswap /swapfile", aws_instance.nat_instance[0].user_data)) && can(regex("iptables-services", aws_instance.nat_instance[0].user_data)) && can(regex("net.ipv4.ip_forward = 1", aws_instance.nat_instance[0].user_data))
    error_message = "User data must create swap, install iptables-services and enable IP forwarding."
  }

  assert {
    condition     = length(aws_route.nat_instance) == 1 && alltrue([for r in aws_route.nat_instance : r.destination_cidr_block == "0.0.0.0/0"])
    error_message = "Every private route table must get a 0.0.0.0/0 route to the NAT instance."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.nat_instance_vpc[0].cidr_ipv4 == "10.0.0.0/16" && aws_vpc_security_group_ingress_rule.nat_instance_vpc[0].ip_protocol == "-1"
    error_message = "The security group must allow all traffic from the VPC CIDR."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.nat_instance_all[0].cidr_ipv4 == "0.0.0.0/0" && aws_vpc_security_group_egress_rule.nat_instance_all[0].ip_protocol == "-1"
    error_message = "The security group must allow all egress."
  }

  assert {
    condition     = endswith(aws_iam_role_policy_attachment.nat_instance_ssm[0].policy_arn, ":iam::aws:policy/AmazonSSMManagedInstanceCore")
    error_message = "The instance role must attach AmazonSSMManagedInstanceCore."
  }
}

run "test_instance_tags_at_creation" {
  command = plan

  assert {
    condition = alltrue([
      for tags in [
        aws_instance.nat_instance[0].tags,
        aws_eip.nat_instance[0].tags,
        aws_security_group.nat_instance[0].tags,
        aws_iam_role.nat_instance[0].tags,
        aws_iam_instance_profile.nat_instance[0].tags,
      ] : tags.Environment == "test" && tags.Application == "example" && tags.Project == "example"
    ])
    error_message = "Every NAT instance resource must carry the module tags (Environment, Application and context.extra_tags) at creation time."
  }
}

run "test_instance_public_ips_output" {
  command = plan

  assert {
    condition     = length(output.nat_public_ips) == 1
    error_message = "nat_public_ips must return the single Elastic IP of the NAT instance."
  }
}

run "test_instance_absent_in_gateway_modes" {
  command = plan

  variables {
    nat = "single"
  }

  assert {
    condition     = length(aws_instance.nat_instance) == 0 && length(aws_eip.nat_instance) == 0 && length(aws_route.nat_instance) == 0 && output.nat_instance_id == null
    error_message = "Gateway modes must create no NAT instance resources."
  }
}

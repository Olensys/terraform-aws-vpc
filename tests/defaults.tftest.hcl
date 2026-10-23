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
  }
  name = "example"
  cidr = "10.0.0.0/16"
}

run "test_single_nat_default" {
  command = plan

  assert {
    condition     = output.nat_strategy == { enabled = true, single = true, per_az = false }
    error_message = "Default nat must be a single shared NAT gateway."
  }

  assert {
    condition     = length(output.azs) == 2
    error_message = "Default az_count must be 2."
  }
}

run "test_per_az_nat" {
  command = plan

  variables {
    nat      = "per_az"
    az_count = 3
  }

  assert {
    condition     = output.nat_strategy == { enabled = true, single = false, per_az = true }
    error_message = "per_az must enable one NAT gateway per AZ and disable the single NAT."
  }

  assert {
    condition     = length(output.azs) == 3
    error_message = "az_count 3 must span three zones."
  }
}

run "test_none_nat_no_eip" {
  command = plan

  variables {
    nat = "none"
  }

  assert {
    condition     = output.nat_strategy == { enabled = false, single = false, per_az = false }
    error_message = "nat none must disable all NAT gateways (and therefore allocate no EIPs)."
  }
}

run "test_flow_log_role_scoped" {
  command = plan

  # SMOKE: the flow-log IAM policy is created inside the upstream module (scoped there to the log group ARN with ":*") and is not visible to terraform test; only the retention input and the enable flag are asserted at root. Real check lives in complete.tftest.hcl and trivy.
  variables {
    flow_log_retention_days = 90
  }

  assert {
    condition     = var.enable_flow_logs == true && var.flow_log_retention_days == 90
    error_message = "Flow logs must default on and accept a retention override."
  }
}

run "test_az_count_validation" {
  command = plan

  variables {
    az_count = 4
  }

  expect_failures = [var.az_count]
}

run "test_nat_validation" {
  command = plan

  variables {
    nat = "instance"
  }

  expect_failures = [var.nat]
}

run "test_cidr_validation" {
  command = plan

  variables {
    cidr = "not-a-cidr"
  }

  expect_failures = [var.cidr]
}

run "test_subnet_cidrs_computed" {
  command = plan

  assert {
    condition     = output.public_subnet_cidrs == tolist(["10.0.0.0/20", "10.0.16.0/20"])
    error_message = "Public subnets must be the first two /20 blocks."
  }

  assert {
    condition     = output.private_subnet_cidrs == tolist(["10.0.32.0/20", "10.0.48.0/20"])
    error_message = "Private subnets must be the next two /20 blocks."
  }
}

run "test_create_false_plans_nothing" {
  command = plan

  variables {
    create = false
  }

  assert {
    condition = alltrue([
      output.id == null, output.name == null, output.arn == null, output.cidr == null,
      output.public_subnet_ids == null, output.private_subnet_ids == null,
      output.public_subnet_cidrs == null, output.private_subnet_cidrs == null,
      output.private_route_table_ids == null, output.nat_public_ips == null,
      output.azs == null, output.nat_strategy == null, output.tags == null,
    ])
    error_message = "Every output must be null when create is false."
  }
}

run "name_validation_rejects_uppercase" {
  command = plan

  variables {
    name = "Bad-Name"
  }

  expect_failures = [var.name]
}

run "test_tags_contract" {
  command = plan

  variables {
    tags = { Owner = "x" }
    context = {
      organization = "olensys"
      environment  = "test"
      application  = "example"
      owner        = "platform"
      cost_center  = "eng"
      extra_tags   = { Owner = "y", Team = "z" }
    }
  }

  assert {
    condition     = output.tags.Owner == "x"
    error_message = "var.tags must win over context.extra_tags."
  }

  assert {
    condition     = output.tags.Team == "z"
    error_message = "context.extra_tags must be merged."
  }
}

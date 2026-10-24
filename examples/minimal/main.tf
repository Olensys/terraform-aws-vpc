terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

module "naming" {
  source = "git::https://github.com/Olensys/terraform-null-naming.git?ref=v1.0.1"

  context = local.context
}

locals {
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "vpc"
    owner        = "platform"
    cost_center  = "eng"
  }
}

module "this" {
  source = "../../"

  name    = module.naming.name
  context = local.context
  cidr    = "10.0.0.0/16"
  tags    = module.naming.tags
}

output "public_subnet_ids" {
  value = module.this.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.this.private_subnet_ids
}

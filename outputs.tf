output "id" {
  description = "ID of the VPC. Null when create is false."
  value       = var.create ? module.this.vpc_id : null
}

output "name" {
  description = "Name of the VPC. Null when create is false."
  value       = var.create ? var.name : null
}

output "arn" {
  description = "ARN of the VPC. Null when create is false."
  value       = var.create ? module.this.vpc_arn : null
}

output "cidr" {
  description = "IPv4 CIDR block of the VPC. Null when create is false."
  value       = var.create ? var.cidr : null
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, one per availability zone. Null when create is false."
  value       = var.create ? module.this.public_subnets : null
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, one per availability zone. Null when create is false."
  value       = var.create ? module.this.private_subnets : null
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets, in availability zone order. Null when create is false."
  value       = var.create ? local.public_subnet_cidrs : null
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets, in availability zone order. Null when create is false."
  value       = var.create ? local.private_subnet_cidrs : null
}

output "private_route_table_ids" {
  description = "IDs of the private route tables. Null when create is false."
  value       = var.create ? module.this.private_route_table_ids : null
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateways (empty when nat is none). Null when create is false."
  value       = var.create ? module.this.nat_public_ips : null
}

output "azs" {
  description = "Availability zones the VPC spans. Null when create is false."
  value       = var.create ? local.azs : null
}

output "nat_strategy" {
  description = "Resolved NAT strategy flags (enabled, single, per_az) passed to the upstream module. Null when create is false."
  value       = var.create ? local.nat_strategy : null
}

output "tags" {
  description = "Tags applied to every taggable resource, with context.extra_tags merged in. Null when create is false."
  value       = var.create ? local.tags : null
}

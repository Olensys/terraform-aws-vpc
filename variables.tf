variable "name" {
  description = "Resource name. Lowercase letters, digits and hyphens."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{1,63}$", var.name))
    error_message = "name must match ^[a-z0-9-]{1,63}$."
  }
}

variable "context" {
  description = "Deployment context used for naming, tagging and environment-dependent defaults."
  type = object({
    organization = string
    environment  = string
    application  = string
    component    = optional(string)
    owner        = string
    cost_center  = string
    extra_tags   = optional(map(string), {})
  })
  validation {
    condition     = contains(["dev", "staging", "prod", "test", "shared"], var.context.environment)
    error_message = "context.environment must be one of dev, staging, prod, test, shared."
  }
}

variable "create" {
  description = "Whether to create any resources. Set false to create nothing."
  type        = bool
  default     = true
}

variable "cidr" {
  description = "IPv4 CIDR block of the VPC. Must be a /24 or larger so each subnet can be a /28 or larger."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.cidr))
    error_message = "cidr must be a valid IPv4 CIDR block."
  }
  validation {
    condition     = can(cidrnetmask(var.cidr)) && tonumber(split("/", var.cidr)[1]) <= 24
    error_message = "cidr prefix length must be 24 or smaller (the VPC is split into subnets with 4 extra bits)."
  }
}

variable "az_count" {
  description = "Number of availability zones to span. One public and one private subnet is created per zone."
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be between 2 and 3."
  }
}

variable "public_subnet_cidrs" {
  description = "Explicit CIDR blocks of the public subnets, one per availability zone, instead of the computed ones. Use it to adopt an existing VPC without replacing its subnets. Null computes them from cidr."
  type        = list(string)
  default     = null
  validation {
    condition     = var.public_subnet_cidrs == null ? true : alltrue([for c in var.public_subnet_cidrs : can(cidrnetmask(c))])
    error_message = "public_subnet_cidrs must be valid IPv4 CIDR blocks."
  }
}

variable "private_subnet_cidrs" {
  description = "Explicit CIDR blocks of the private subnets, one per availability zone, instead of the computed ones. Null computes them from cidr."
  type        = list(string)
  default     = null
  validation {
    condition     = var.private_subnet_cidrs == null ? true : alltrue([for c in var.private_subnet_cidrs : can(cidrnetmask(c))])
    error_message = "private_subnet_cidrs must be valid IPv4 CIDR blocks."
  }
}

variable "nat" {
  description = "NAT gateway strategy: none (no NAT), single (one shared NAT gateway), per_az (one NAT gateway per availability zone)."
  type        = string
  default     = "single"
  validation {
    condition     = contains(["none", "single", "per_az"], var.nat)
    error_message = "nat must be one of none, single, per_az."
  }
}

variable "enable_flow_logs" {
  description = "Whether to send VPC flow logs to a CloudWatch log group owned by this module."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention in days of the flow log CloudWatch log group."
  type        = number
  default     = 30
}

variable "public_subnet_tags" {
  description = "Extra tags for public subnets, e.g. kubernetes.io/role/elb for load balancer discovery."
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Extra tags for private subnets, e.g. kubernetes.io/role/internal-elb for internal load balancer discovery."
  type        = map(string)
  default     = {}
}

# GCP modules rename this variable to `labels` and add `project_id` after `context`.
variable "tags" {
  description = "Tags merged onto every taggable resource, applied last."
  type        = map(string)
  default     = {}
}

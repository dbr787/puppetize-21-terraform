variable "project_id" {
  description = "An identifier for this project. Used for prefixing resource names and tagging resources."
  type        = string
  validation {
    condition     = length(var.project_id) <= 8
    error_message = "The project_id variable must 8 characters or less."
  }
}

variable "private_zone_name" {
  description = "The name of an existing private hosted zone in Route 53 to associate with the newly created VPC."
  type        = string
}

variable "vpc_cidr" {
  description = "The cidr block for the VPC being created."
  type        = string
}

variable "public_subnet_a_cidr" {
  description = "The cidr block for the primary public subnet being created."
  type        = string
}

variable "public_subnet_b_cidr" {
  description = "The cidr block for the secondary public subnet being created."
  type        = string
}

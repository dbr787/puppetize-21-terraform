variable "project_id" {
  description = "An identifier for this project. Used for prefixing resource names and tagging resources."
  type        = string
  validation {
    condition     = length(var.project_id) <= 8
    error_message = "The project_id variable must 8 characters or less."
  }
}

variable "public_zone_name" {
  description = "The name of an existing public hosted zone in Route 53 to use for creating public DNS records."
  type        = string
}

variable "private_zone_name" {
  description = "The name of an existing private hosted zone in Route 53 to use for creating private DNS records."
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC to use."
  type        = string
}

variable "public_subnet_a_cidr" {
  description = "The CIDR block for the primary public subnet to use."
  type        = string
}

variable "public_subnet_b_cidr" {
  description = "The CIDR block for the secondary public subnet to use."
  type        = string
}

variable "allowed_ip_cidrs" {
  description = "A list of IP addresses in CIDR notation that are allowed access to resources."
  type        = list(any)
  default     = ["0.0.0.0/0"]
}

variable "pe_primary_private_dns" {
  description = "The private DNS record for the Puppet Enterprise primary server. Used in bootstrap scripts to download the Puppet agent."
  type        = string
}

variable "pe_primary_public_dns" {
  description = "The public dns record for connection to the Puppet Enterprise primary server. Used in the destroy provisioner to purge nodes from puppet."
  type        = string
}

variable "pe_primary_ssh_private_key" {
  description = "The SSH key for connection to the Puppet Enterprise primary server. Used in the destroy provisioner to purge nodes from puppet."
  type        = string
}

variable "pe_primary_ssh_user" {
  description = "The SSH user for connection to the Puppet Enterprise primary server. Used in the destroy provisioner to purge nodes from puppet."
  type        = string
}

variable "id" {
  description = "The unique id for the node object. Used to identify the resources created in the iteration of the nodes module."
  type        = string
}

variable "platform" {
  description = "The platform of the node(s) operating system."
  type        = string
  validation {
    condition     = contains(["linux", "windows"], var.platform)
    error_message = "The platform variable must be either linux or windows."
  }
}

variable "instance_count" {
  description = "The number of instances (nodes) to deploy matching the configuration provided in the nodes object."
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "The ec2 instance type for the node(s)."
  type        = string
  default     = "t2.medium"
}

variable "ssh_user" {
  description = "The SSH user to use for provisioners. This will be different for different operating systems."
  type        = string
  default     = "ec2-user"
}

variable "ami_owner" {
  description = "The owner to use in the node_ami data source to identify the ec2 ami to use."
  type        = string
  default     = "309956199498"
}

variable "ami_name_filter" {
  description = "The name filter to use in the node_ami data source to identify the ec2 ami to use."
  type        = string
  default     = "RHEL-7.9_HVM_GA*"
}

variable "role" {
  description = "The Puppet role to assign to the node(s)."
  type        = string
  default     = ""
}

variable "environment" {
  description = "The Puppet environment to assign to the node(s)."
  type        = string
  default     = "production"
}

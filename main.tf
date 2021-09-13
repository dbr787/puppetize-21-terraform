terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.42.0"
    }
  }
  required_version = ">= 0.15.4"
}

module "core-infra" {
  source               = "./modules/core-infra"
  count                = var.create_vpc_and_subnets ? 1 : 0
  project_id           = var.project_id
  private_zone_name    = var.private_zone_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_a_cidr = var.public_subnet_a_cidr
  public_subnet_b_cidr = var.public_subnet_b_cidr
}

module "puppet-enterprise" {
  source                     = "./modules/puppet-enterprise"
  project_id                 = var.project_id
  public_zone_name           = var.public_zone_name
  private_zone_name          = var.private_zone_name
  vpc_cidr                   = var.vpc_cidr
  public_subnet_a_cidr       = var.public_subnet_a_cidr
  public_subnet_b_cidr       = var.public_subnet_b_cidr
  allowed_ip_cidrs           = var.allowed_ip_cidrs
  pe_version                 = var.pe_version
  pe_primary_instance_type   = var.pe_primary_instance_type
  pe_primary_ssh_user        = var.pe_primary_ssh_user
  pe_primary_ami_owner       = var.pe_primary_ami_owner
  pe_primary_ami_name_filter = var.pe_primary_ami_name_filter
  pe_primary_role            = var.pe_primary_role
  pe_primary_environment     = var.pe_primary_environment
  control_repo               = var.control_repo
  github_token               = var.github_token
  depends_on = [
    module.core-infra
  ]
}

# This module will be applied for every object in the nodes variable
module "nodes" {
  source                     = "./modules/nodes"
  for_each                   = { for node in var.nodes : node.id => node }
  project_id                 = var.project_id
  public_zone_name           = var.public_zone_name
  private_zone_name          = var.private_zone_name
  vpc_cidr                   = var.vpc_cidr
  public_subnet_a_cidr       = var.public_subnet_a_cidr
  public_subnet_b_cidr       = var.public_subnet_b_cidr
  allowed_ip_cidrs           = var.allowed_ip_cidrs
  pe_primary_private_dns     = "${var.project_id}-pe-primary.${var.private_zone_name}"
  pe_primary_public_dns      = "${var.project_id}-pe-primary.${var.public_zone_name}"
  pe_primary_ssh_private_key = module.puppet-enterprise.puppet_enterprise.ssh_private_key
  pe_primary_ssh_user        = var.pe_primary_ssh_user
  id                         = each.value.id
  platform                   = try(each.value.platform, "linux")
  instance_count             = try(each.value.instance_count, 1)
  instance_type              = try(each.value.instance_type, "t2.medium")
  ssh_user                   = try(each.value.ssh_user, "ec2-user")
  ami_owner                  = try(each.value.ami_owner, "309956199498")
  ami_name_filter            = try(each.value.ami_name_filter, "RHEL-7.9_HVM_GA*")
  role                       = try(each.value.role, "")
  environment                = try(each.value.environment, "production")
  depends_on = [
    module.core-infra
  ]
}

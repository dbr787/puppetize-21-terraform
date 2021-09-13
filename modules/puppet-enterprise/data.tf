data "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
}

data "aws_subnet" "public_subnet_a" {
  cidr_block = var.public_subnet_a_cidr
  vpc_id     = data.aws_vpc.vpc.id
}

data "aws_subnet" "public_subnet_b" {
  cidr_block = var.public_subnet_b_cidr
  vpc_id     = data.aws_vpc.vpc.id
}

data "aws_route53_zone" "public_zone" {
  name = var.public_zone_name
}

data "aws_route53_zone" "private_zone" {
  name         = var.private_zone_name
  private_zone = true
}

data "aws_acm_certificate" "certificate" {
  domain = "*.${var.public_zone_name}"
  types  = ["AMAZON_ISSUED"]
}

data "aws_ami" "pe_primary_ami" {
  most_recent = true
  owners      = [var.pe_primary_ami_owner]
  filter {
    name   = "name"
    values = [var.pe_primary_ami_name_filter]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

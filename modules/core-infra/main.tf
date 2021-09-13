terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.42.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.1.0"
    }
  }
  required_version = ">= 0.15.4"
}

# create vpc
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = "true"
  tags = {
    Name = "${var.project_id}-vpc"
  }
}

# create public subnet 1/2 (2 subnets required for load balancer)
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_a_cidr
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.availability_zones.names[0]
  tags = {
    Name = "${var.project_id}-public-subnet-a"
  }
}

# create public subnet (2/2) (2 subnets required for load balancer)
resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_b_cidr
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.availability_zones.names[1]
  tags = {
    Name = "${var.project_id}-public-subnet-b"
  }
}

# create internet gateway for newly created vpc
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.project_id}-internet-gateway"
  }
}

# create route table for newly created vpc
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name = "${var.project_id}-public-route-table"
  }
}

# associate route table with newly created public subnet 1/2
resource "aws_route_table_association" "public_subnet_a_route_table_assoc" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_route_table.id
}

# associate route table with newly created public subnet 2/2
resource "aws_route_table_association" "public_subnet_b_route_table_assoc" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_route_table.id
}

# ensure newly created vpc is associated with the existing private zone
resource "aws_route53_zone_association" "private_zone_association" {
  zone_id = data.aws_route53_zone.private_zone.zone_id
  vpc_id  = aws_vpc.vpc.id
}

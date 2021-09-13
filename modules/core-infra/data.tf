data "aws_availability_zones" "availability_zones" {
  state = "available"
}

data "aws_route53_zone" "private_zone" {
  name         = var.private_zone_name
  private_zone = true
}

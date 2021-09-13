terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.42.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.1.0"
    }
  }
  required_version = ">= 0.15.4"
}

# create ssh key for pe_primary aws instance
resource "tls_private_key" "ssh_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
  provisioner "local-exec" {
    command = <<-EOT
    echo '${self.private_key_pem}' > ~/.ssh/${var.project_id}-pe-primary-key.pem
    chmod 600 ~/.ssh/${var.project_id}-pe-primary-key.pem
    EOT
  }
}

# create aws key pair for pe_primary aws instance
resource "aws_key_pair" "ssh_key_pair" {
  key_name   = "${var.project_id}-pe-primary-ssh-key-pair"
  public_key = tls_private_key.ssh_private_key.public_key_openssh
  tags = {
    Name = "${var.project_id}-pe-primary-ssh-key-pair"
  }
}

# create password for puppet enterprise admin user
resource "random_string" "pe_admin_password" {
  length  = 8
  special = false
}


# create pe_primary aws instance
resource "aws_instance" "pe_primary" {
  ami                    = data.aws_ami.pe_primary_ami.id
  instance_type          = var.pe_primary_instance_type
  subnet_id              = data.aws_subnet.public_subnet_a.id
  vpc_security_group_ids = [aws_security_group.pe_primary_sg.id]
  key_name               = aws_key_pair.ssh_key_pair.id
  # copy bootstrap script
  provisioner "file" {
    content = templatefile("${path.module}/files/pe_bootstrap.tpl.sh", {
      hostname          = "${var.project_id}-pe-primary"
      zone              = "${var.private_zone_name}"
      pe_version        = "${var.pe_version}"
      pe_admin_password = "${random_string.pe_admin_password.result}"
      role              = "${var.pe_primary_role}"
      environment       = "${var.pe_primary_environment}"
      control_repo      = "${var.control_repo}"
      github_token      = "${var.github_token}" != "" ? file("${var.github_token}") : ""
      code_manager_dns  = "https://${var.project_id}-pe.${var.public_zone_name}:8170"
    })
    destination = "/tmp/bootstrap.sh"
    connection {
      type        = "ssh"
      user        = var.pe_primary_ssh_user
      host        = self.public_ip
      private_key = tls_private_key.ssh_private_key.private_key_pem
    }
  }
  # run bootstrap script
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/bootstrap.sh",
      "nohup sudo bash /tmp/bootstrap.sh &> /tmp/bootstrap.log &", # run script in background on server and send output to log
      "sleep 1",
    ]
    connection {
      type        = "ssh"
      user        = var.pe_primary_ssh_user
      host        = self.public_ip
      private_key = tls_private_key.ssh_private_key.private_key_pem
    }
  }
  tags = {
    Name           = "${var.project_id}-pe-primary"
    hostname       = "${var.project_id}-pe-primary"
    pp_role        = var.pe_primary_role
    pp_environment = var.pe_primary_environment
  }
}

# create pe_primary security group
resource "aws_security_group" "pe_primary_sg" {
  vpc_id = data.aws_vpc.vpc.id
  name   = "${var.project_id}-pe-primary-sg"
  egress {
    description = "Outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Outbound ping to internal subnets"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"]
  }
  ingress {
    description = "Inbound ping from allowed ips and internal subnets"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = setunion(var.allowed_ip_cidrs, ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"])
  }
  ingress {
    description = "Inbound ssh from allowed ips and internal subnets"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = setunion(var.allowed_ip_cidrs, ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"])
  }
  ingress {
    description = "Inbound https from allowed ips and internal subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = setunion(var.allowed_ip_cidrs, ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"])
  }
  ingress {
    description = "Inbound puppet required port from allowed ips and internal subnets"
    from_port   = 4433
    to_port     = 4433
    protocol    = "tcp"
    cidr_blocks = setunion(var.allowed_ip_cidrs, ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"])
  }
  ingress {
    description = "Inbound puppet required port from allowed ips and internal subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = setunion(var.allowed_ip_cidrs, ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"])
  }
  ingress {
    description = "Inbound puppet required port from allowed ips and internal subnets"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = setunion(var.allowed_ip_cidrs, ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"])
  }
  ingress {
    description = "Inbound puppet required port from allowed ips and internal subnets"
    from_port   = 8140
    to_port     = 8140
    protocol    = "tcp"
    cidr_blocks = setunion(var.allowed_ip_cidrs, ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"])
  }
  ingress {
    description = "Inbound puppet required port from allowed ips and internal subnets"
    from_port   = 8142
    to_port     = 8142
    protocol    = "tcp"
    cidr_blocks = setunion(var.allowed_ip_cidrs, ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"])
  }
  ingress {
    description = "Inbound puppet required port from allowed ips and internal subnets"
    from_port   = 8143
    to_port     = 8143
    protocol    = "tcp"
    cidr_blocks = setunion(var.allowed_ip_cidrs, ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"])
  }
  ingress {
    from_port   = 8170
    to_port     = 8170
    protocol    = "tcp"
    cidr_blocks = setunion(var.allowed_ip_cidrs, ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"])
  }
  tags = {
    Name = "${var.project_id}-pe-primary-sg"
  }
}

# create pe_primary private dns record (for server connection from inside the vpc)
resource "aws_route53_record" "pe_primary_private_dns" {
  zone_id = data.aws_route53_zone.private_zone.zone_id
  name    = "${var.project_id}-pe-primary"
  type    = "A"
  ttl     = 300
  records = [aws_instance.pe_primary.private_ip]
}

# create pe_primary public dns record (for server connection from internet)
resource "aws_route53_record" "pe_primary_public_dns" {
  zone_id = data.aws_route53_zone.public_zone.zone_id
  name    = "${var.project_id}-pe-primary"
  type    = "A"
  ttl     = 300
  records = [aws_instance.pe_primary.public_ip]
}


# create application load balancer
resource "aws_alb" "alb" {
  name            = "${var.project_id}-alb"
  security_groups = [aws_security_group.alb_sg.id]
  subnets         = ["${data.aws_subnet.public_subnet_a.id}", "${data.aws_subnet.public_subnet_b.id}"]
  tags = {
    Name = "${var.project_id}-alb"
  }
}

# create application load balancer dns record
resource "aws_route53_record" "alb_dns" {
  zone_id = data.aws_route53_zone.public_zone.zone_id
  name    = "${var.project_id}-pe"
  type    = "A"
  alias {
    name                   = aws_alb.alb.dns_name
    zone_id                = aws_alb.alb.zone_id
    evaluate_target_health = false
  }
}

# create application load balancer security group
resource "aws_security_group" "alb_sg" {
  vpc_id = data.aws_vpc.vpc.id
  name   = "${var.project_id}-alb-sg"
  ingress {
    description = "Inbound http from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Inbound https from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Outbound https to internal subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"]
  }
  ingress {
    description = "Inbound puppet required port from internet"
    from_port   = 8143
    to_port     = 8143
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Outbound puppet required port to internal subnets"
    from_port   = 8143
    to_port     = 8143
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"]
  }
  ingress {
    description = "Inbound puppet required port from internet"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Outbound puppet required port to internal subnets"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"]
  }
  ingress {
    description = "Inbound code manager port from internet"
    from_port   = 8170
    to_port     = 8170
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Outbound code manager port to internal subnets"
    from_port   = 8170
    to_port     = 8170
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"]
  }
  tags = {
    Name = "${var.project_id}-alb-sg"
  }
}

# create application load balancer listener to redirect http to https (80 -> 443)
resource "aws_alb_listener" "alb_listener_http" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  tags = {
    Name = "${var.project_id}-alb-ls-http"
  }
}

# create application load balancer listener for https connections (443)
resource "aws_alb_listener" "alb_listener_https" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.certificate.arn
  default_action {
    target_group_arn = aws_alb_target_group.alb_target_group_https.arn
    type             = "forward"
  }
  tags = {
    Name = "${var.project_id}-alb-ls-https"
  }
}

# create application load balancer listener for puppetdb connections (8081)
resource "aws_alb_listener" "alb_listener_puppetdb" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "8081"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.certificate.arn
  default_action {
    target_group_arn = aws_alb_target_group.alb_target_group_puppetdb.arn
    type             = "forward"
  }
  tags = {
    Name = "${var.project_id}-alb-ls-https"
  }
}

# create application load balancer listener for orchestrator connections (8143)
resource "aws_alb_listener" "alb_listener_orchestrator" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "8143"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.certificate.arn
  default_action {
    target_group_arn = aws_alb_target_group.alb_target_group_orchestrator.arn
    type             = "forward"
  }
  tags = {
    Name = "${var.project_id}-alb-ls-https"
  }
}

# create application load balancer listener for code manager connections (8170)
resource "aws_alb_listener" "alb_listener_code_manager" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "8170"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.certificate.arn
  default_action {
    target_group_arn = aws_alb_target_group.alb_target_group_code_manager.arn
    type             = "forward"
  }
  tags = {
    Name = "${var.project_id}-alb-ls-code-manager"
  }
}

# create application load balancer target group for https connections (443)
resource "aws_alb_target_group" "alb_target_group_https" {
  name     = "${var.project_id}-alb-tg-https"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = data.aws_vpc.vpc.id
  tags = {
    Name = "${var.project_id}-alb-tg-https"
  }
}

# create application load balancer target group for puppetdb connections (8081)
resource "aws_alb_target_group" "alb_target_group_puppetdb" {
  name     = "${var.project_id}-alb-tg-puppetdb"
  port     = 8081
  protocol = "HTTPS"
  vpc_id   = data.aws_vpc.vpc.id
  tags = {
    Name = "${var.project_id}-alb-tg-puppetdb"
  }
}

# create application load balancer target group for orchestrator connections (8143)
resource "aws_alb_target_group" "alb_target_group_orchestrator" {
  name     = "${var.project_id}-alb-tg-orchestrator"
  port     = 8143
  protocol = "HTTPS"
  vpc_id   = data.aws_vpc.vpc.id
  tags = {
    Name = "${var.project_id}-alb-tg-orchestrator"
  }
}

# create application load balancer target group for code manager connections (8170)
resource "aws_alb_target_group" "alb_target_group_code_manager" {
  name     = "${var.project_id}-alb-tg-code-manager"
  port     = 8170
  protocol = "HTTPS"
  vpc_id   = data.aws_vpc.vpc.id
  tags = {
    Name = "${var.project_id}-alb-tg-code-manager"
  }
}

# create application load balancer target group attachment for https connections (443)
resource "aws_alb_target_group_attachment" "alb_target_group_attachment_https" {
  target_group_arn = aws_alb_target_group.alb_target_group_https.arn
  target_id        = aws_instance.pe_primary.id
  port             = 443
}

# create application load balancer target group attachment for puppetdb connections (8081)
resource "aws_alb_target_group_attachment" "alb_target_group_attachment_puppetdb" {
  target_group_arn = aws_alb_target_group.alb_target_group_puppetdb.arn
  target_id        = aws_instance.pe_primary.id
  port             = 8081
}

# create application load balancer target group attachment for orchestrator connections (8143)
resource "aws_alb_target_group_attachment" "alb_target_group_attachment_orchestrator" {
  target_group_arn = aws_alb_target_group.alb_target_group_orchestrator.arn
  target_id        = aws_instance.pe_primary.id
  port             = 8143
}

# create application load balancer target group attachment for code manager connections (8170)
resource "aws_alb_target_group_attachment" "alb_target_group_attachment_code_manager" {
  target_group_arn = aws_alb_target_group.alb_target_group_code_manager.arn
  target_id        = aws_instance.pe_primary.id
  port             = 8170
}

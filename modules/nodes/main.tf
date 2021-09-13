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

# pick a random subnet to use for nodes
resource "random_shuffle" "subnet" {
  input        = ["${data.aws_subnet.public_subnet_a.id}", "${data.aws_subnet.public_subnet_b.id}"]
  result_count = 1
}

# create ssh key for nodes
resource "tls_private_key" "ssh_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
  provisioner "local-exec" {
    command = <<-EOT
    echo '${self.private_key_pem}' > ~/.ssh/${var.project_id}-${var.id}-key.pem
    chmod 600 ~/.ssh/${var.project_id}-${var.id}-key.pem
    EOT
  }
}

# create aws key pair for nodes
resource "aws_key_pair" "ssh_key_pair" {
  key_name   = "${var.project_id}-${var.id}-ssh-key-pair"
  public_key = tls_private_key.ssh_private_key.public_key_openssh
  tags = {
    Name = "${var.project_id}-${var.id}-ssh-key-pair"
  }
}

# create linux aws instances if platform is linux
resource "aws_instance" "linux" {
  ami                    = data.aws_ami.node_ami.id
  count                  = var.platform == "linux" ? var.instance_count : 0
  instance_type          = var.instance_type
  subnet_id              = random_shuffle.subnet.result[0]
  vpc_security_group_ids = [aws_security_group.node_sg.id]
  key_name               = aws_key_pair.ssh_key_pair.id
  # copy bootstrap script
  provisioner "file" {
    content = templatefile("${path.module}/files/nix_bootstrap.tpl.sh", {
      hostname    = "${var.project_id}-${var.id}-${format("%02d", count.index + 1)}"
      zone        = "${var.private_zone_name}"
      pe_primary  = "${var.pe_primary_private_dns}"
      role        = "${var.role}"
      environment = "${var.environment}"
    })
    destination = "/tmp/bootstrap.sh"
    connection {
      type        = "ssh"
      user        = var.ssh_user
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
      user        = var.ssh_user
      host        = self.public_ip
      private_key = tls_private_key.ssh_private_key.private_key_pem
    }
  }
  tags = {
    Name           = "${var.project_id}-${var.id}-${format("%02d", count.index + 1)}"
    hostname       = "${var.project_id}-${var.id}-${format("%02d", count.index + 1)}"
    pp_role        = var.role
    pp_environment = var.environment
  }
}

# create windows aws instances if platform is windows
resource "aws_instance" "windows" {
  ami                    = data.aws_ami.node_ami.id
  count                  = var.platform == "windows" ? var.instance_count : 0
  instance_type          = var.instance_type
  subnet_id              = random_shuffle.subnet.result[0]
  vpc_security_group_ids = [aws_security_group.node_sg.id]
  key_name               = aws_key_pair.ssh_key_pair.id
  get_password_data      = true
  user_data = templatefile("${path.module}/files/win_bootstrap.tpl.ps1", {
    hostname    = "${var.project_id}-${var.id}-${format("%02d", count.index + 1)}"
    zone        = "${var.private_zone_name}"
    pe_primary  = "${var.pe_primary_private_dns}"
    role        = "${var.role}"
    environment = "${var.environment}"
  })
  tags = {
    Name           = "${var.project_id}-${var.id}-${format("%02d", count.index + 1)}"
    hostname       = "${var.project_id}-${var.id}-${format("%02d", count.index + 1)}"
    pp_role        = var.role
    pp_environment = var.environment
  }
}

# purge node from puppet on destroy (executes on pe_primary)
# must use null_resource for destroy provisioner
# https://www.terraform.io/upgrade-guides/0-13.html#destroy-time-provisioners-may-not-refer-to-other-resources
resource "null_resource" "node_destroy" {
  count = var.instance_count
  triggers = {
    certname    = "${var.project_id}-${var.id}-${format("%02d", count.index + 1)}.${var.private_zone_name}"
    host        = var.pe_primary_public_dns
    user        = var.pe_primary_ssh_user
    private_key = var.pe_primary_ssh_private_key
    platform    = var.platform
    ami         = data.aws_ami.node_ami.id
  }
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [
      "sudo /opt/puppetlabs/bin/puppet node purge ${self.triggers.certname}",
    ]
    connection {
      type        = "ssh"
      user        = self.triggers.user
      host        = self.triggers.host
      private_key = self.triggers.private_key
      timeout     = "10s"
    }
  }
}

# create security group for nodes
resource "aws_security_group" "node_sg" {
  vpc_id = data.aws_vpc.vpc.id
  name   = "${var.project_id}-${var.id}-sg"
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
    description = "Inbound rdp from allowed ips and internal subnets"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = setunion(var.allowed_ip_cidrs, ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"])
  }
  ingress {
    description = "Inbound puppet required port from internal subnets"
    from_port   = 8140
    to_port     = 8140
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"]
  }
  ingress {
    description = "Inbound puppet required port from internal subnets"
    from_port   = 8142
    to_port     = 8142
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_subnet.public_subnet_a.cidr_block}", "${data.aws_subnet.public_subnet_b.cidr_block}"]
  }
  tags = {
    Name = "${var.project_id}-${var.id}-sg"
  }
}

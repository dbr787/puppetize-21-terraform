output "puppet_enterprise" {
  value = {
    "public_dns"         = aws_instance.pe_primary.public_dns,
    "public_ip"          = aws_instance.pe_primary.public_ip,
    "private_dns"        = aws_instance.pe_primary.private_dns,
    "private_ip"         = aws_instance.pe_primary.private_ip
    "instance_id"        = aws_instance.pe_primary.id,
    "instance_state"     = aws_instance.pe_primary.instance_state,
    "instance_name"      = aws_instance.pe_primary.tags.Name
    "instance_hostname"  = aws_instance.pe_primary.tags.hostname
    "custom_private_dns" = aws_route53_record.pe_primary_private_dns.fqdn
    "custom_public_dns"  = aws_route53_record.pe_primary_public_dns.fqdn
    "allowed_ip_cidrs"   = [for detail in var.allowed_ip_cidrs : detail]
    "pe_console_dns"     = aws_route53_record.alb_dns.fqdn,
    "ssh_private_key"    = tls_private_key.ssh_private_key.private_key_pem
    "ssh_command"        = "ssh -i ~/.ssh/${var.project_id}-pe-primary-key.pem ${var.pe_primary_ssh_user}@${aws_instance.pe_primary.public_ip} -o StrictHostKeyChecking=no"
    "pe_console_url"     = "https://${aws_route53_record.alb_dns.fqdn}/"
    "pe_admin_password"  = random_string.pe_admin_password.result
  }
  sensitive = true
}

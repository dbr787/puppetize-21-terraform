output "nodes" {
  value = flatten([
    [for index, instance in aws_instance.windows :
      {
        "public_dns"     = instance.public_dns,
        "public_ip"      = instance.public_ip,
        "private_dns"    = instance.private_dns,
        "private_ip"     = instance.private_ip
        "instance_id"    = instance.id,
        "instance_state" = instance.instance_state,
        "instance_name"  = instance.tags.Name,
        "instance_type"  = var.instance_type,
        "platform"       = var.platform,
        "role"           = var.role,
        "environment"    = var.environment
        "password"       = "${rsadecrypt(instance.password_data, tls_private_key.ssh_private_key.private_key_pem)}"
      }
    ],
    [for index, instance in aws_instance.linux :
      {
        "public_dns"     = instance.public_dns,
        "public_ip"      = instance.public_ip,
        "private_dns"    = instance.private_dns,
        "private_ip"     = instance.private_ip
        "instance_id"    = instance.id,
        "instance_state" = instance.instance_state,
        "instance_name"  = instance.tags.Name,
        "instance_type"  = var.instance_type,
        "platform"       = var.platform,
        "role"           = var.role,
        "environment"    = var.environment,
        "ssh_command"    = "ssh -i ~/.ssh/${var.project_id}-${var.id}-key.pem ${var.ssh_user}@${instance.public_ip} -o StrictHostKeyChecking=no"
      }
    ]
  ])
  sensitive = true
}

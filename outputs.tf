output "puppet_enterprise" {
  value     = module.puppet-enterprise.puppet_enterprise
  sensitive = true
}

output "nodes" {
  value = flatten([
    for mod in module.nodes : mod.nodes
  ])
  sensitive = true
}

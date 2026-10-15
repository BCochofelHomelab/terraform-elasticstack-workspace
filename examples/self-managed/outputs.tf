output "space_id" {
  description = "The workspace's Kibana space."
  value       = module.workspace.space_id
}

output "namespace" {
  description = "Namespace to set on the workspace's integration policies and outputs."
  value       = module.workspace.namespace
}

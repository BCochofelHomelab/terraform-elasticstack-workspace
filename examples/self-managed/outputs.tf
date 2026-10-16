output "space_id" {
  description = "The workspace's Kibana space."
  value       = module.workspace.space_id
}

output "data_view_ids" {
  description = "The workspace's data views, by key."
  value       = module.workspace.data_view_ids
}

output "role_names" {
  description = "The workspace's roles, by kind."
  value       = module.workspace.role_names
}

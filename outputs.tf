output "space_id" {
  description = "The Kibana space id (the workspace id)."
  value       = elasticstack_kibana_space.this.space_id
}

output "data_view_ids" {
  description = "Data view ids by key: `<type>` for the workspace's own, `<type>/<workspace>` for each read_from workspace."
  value       = { for k, v in elasticstack_kibana_data_view.this : k => v.data_view.id }
}

output "default_data_view_id" {
  description = "The id of the space's default data view."
  value       = elasticstack_kibana_default_data_view.this.data_view_id
}

output "index_patterns" {
  description = "The index patterns the workspace's roles may read."
  value       = local.index_patterns
}

output "role_names" {
  description = "The workspace's role names, by kind (`viewer`, `editor`): bound to groups by the module, or given to native users directly."
  value       = { for k, v in elasticstack_kibana_security_role.this : k => v.name }
}

output "role_mapping_names" {
  description = "The role mappings created, by kind: only the kinds with groups in access."
  value       = { for k, v in elasticstack_elasticsearch_security_role_mapping.this : k => v.name }
}

output "baseline_saved_objects" {
  description = "The baseline templates imported, by name, with how many objects each imported."
  value       = { for k, v in elasticstack_kibana_import_saved_objects.baseline : k => v.success_count }
}

output "connector_ids" {
  description = "The connectors created in the space, by key."
  value       = { for k, v in elasticstack_kibana_action_connector.this : k => v.connector_id }
}

output "rule_ids" {
  description = "The alerting rules' ids, by key: `baseline_no_data`, `baseline_error_rate`, then the workspace's own."
  value       = { for k, v in elasticstack_kibana_alerting_rule.this : k => v.rule_id }
}

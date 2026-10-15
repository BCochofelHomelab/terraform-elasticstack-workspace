output "space_id" {
  description = "Kibana space id (equals the workspace id)."
  value       = elasticstack_kibana_space.this.space_id
}

output "namespace" {
  description = "The namespace this workspace's data must be written with: set it on Fleet integration policies, APM and Logstash outputs."
  value       = var.workspace
}

output "index_patterns" {
  description = "Index pattern per data type, e.g. { logs = \"logs-*-payments\" }."
  value       = local.index_patterns
}

output "data_view_ids" {
  description = "Data view id per data type. Workspace saved objects reference these."
  value       = { for k, v in elasticstack_kibana_data_view.this : k => v.data_view.id }
}

output "role_names" {
  description = "Role name per access level (viewer, editor)."
  value       = { for k, v in elasticstack_kibana_security_role.this : k => v.name }
}

output "alerts_index" {
  description = "Index the workspace's index connector writes alert documents to."
  value       = local.alerts_index
}

output "connector_ids" {
  description = "Connector ids every rule notifies, index connector first."
  value       = [for a in local.actions : a.connector_id]
}

output "rule_ids" {
  description = "Rule ids keyed by rule key: error_rate, no_data and every key of var.rules."
  value       = { for k, v in elasticstack_kibana_alerting_rule.this : k => v.rule_id }
}

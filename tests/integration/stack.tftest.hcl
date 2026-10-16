# Integration tests: real applies against the throwaway Elasticsearch and
# Kibana that scripts/integration.sh starts. tofu test destroys everything
# at the end. The provider reads its endpoints and credentials from the
# environment (ELASTICSEARCH_*, KIBANA_*), which the script sets.
#
#   scripts/integration.sh

# The empty blocks matter: without an elasticsearch block, the provider
# ignores ELASTICSEARCH_ENDPOINTS and the Elasticsearch resources fail with
# "Elasticsearch client not configured".
provider "elasticstack" {
  elasticsearch {}
  kibana {}
}

variables {
  workspace_id = "it_workspace"
  display_name = "Integration test"
  description  = "Created by tests/integration; safe to delete."
  color        = "#1EA593"
  read_from    = ["it_other"]
  access = {
    realm         = "it_realm"
    viewer_groups = ["it-viewers"]
    editor_groups = ["it-editors"]
  }

  # .server-log: one of the two connector types the basic license allows.
  connectors = {
    log = { type = ".server-log", name = "Server log" }
  }
  alert_actions = [{
    connector = "log"
    params    = "{\"level\":\"warn\",\"message\":\"{{rule.name}}: {{context.reason}}{{context.message}}\"}"
  }]

  # A workspace export, data view and summary line included, as Kibana
  # writes it: the module drops both.
  saved_objects = {
    "dashboards/it.ndjson" = <<-EOT
      {"type":"index-pattern","id":"it_workspace-logs","attributes":{"title":"logs-*-it_workspace","timeFieldName":"@timestamp"},"references":[]}
      {"type":"search","id":"it_workspace-it-search","attributes":{"title":"IT search","columns":["message"],"sort":[["@timestamp","desc"]],"kibanaSavedObjectMeta":{"searchSourceJSON":"{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"}},"references":[{"name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern","id":"it_workspace-logs"}],"coreMigrationVersion":"8.8.0","typeMigrationVersion":"8.0.0"}
      {"exportedCount":2,"missingRefCount":0,"missingReferences":[]}
    EOT
  }

  rules = {
    it_rule = {
      name         = "IT rule"
      rule_type_id = ".es-query"
      interval     = "5m"
      params       = "{\"searchType\":\"esQuery\",\"index\":[\"logs-*-it_workspace\"],\"timeField\":\"@timestamp\",\"esQuery\":\"{\\\"query\\\":{\\\"match_all\\\":{}}}\",\"size\":0,\"threshold\":[100],\"thresholdComparator\":\">\",\"timeWindowSize\":5,\"timeWindowUnit\":\"m\"}"
    }
  }
}

run "create" {
  assert {
    condition     = output.space_id == "it_workspace"
    error_message = "The space was created with the workspace id."
  }

  assert {
    condition     = output.default_data_view_id == "it_workspace-logs"
    error_message = "The logs data view is the space's default."
  }

  assert {
    condition     = elasticstack_kibana_data_view.this["logs/it_other"].space_id == "it_workspace"
    error_message = "read_from data views live in the reading workspace's space."
  }

  assert {
    condition     = length(output.role_mapping_names) == 2
    error_message = "Both role mappings were created."
  }

  assert {
    condition     = output.baseline_saved_objects == { overview = 3 }
    error_message = "The baseline imported its dashboard and two searches."
  }

  assert {
    condition     = elasticstack_kibana_import_saved_objects.workspace["dashboards/it.ndjson"].success_count == 1
    error_message = "The workspace export imported its search, not the data view."
  }

  assert {
    condition     = keys(output.rule_ids) == ["baseline_error_rate", "baseline_no_data", "it_rule"]
    error_message = "The baseline rules and the workspace's rule exist."
  }

  assert {
    condition     = alltrue([for r in elasticstack_kibana_alerting_rule.this : length(r.actions) == 1])
    error_message = "Every rule sends to the server-log connector."
  }
}

run "update_in_place" {
  variables {
    display_name = "Integration test (renamed)"
    data_types   = ["logs", "metrics"]
  }

  assert {
    condition     = elasticstack_kibana_space.this.name == "Integration test (renamed)" && elasticstack_kibana_space.this.space_id == "it_workspace"
    error_message = "A new display name renames the space; its id never changes."
  }

  assert {
    condition     = !contains(keys(output.data_view_ids), "traces")
    error_message = "Dropping a data type removes its data view."
  }

  assert {
    condition     = output.index_patterns == ["logs-*-it_workspace", "metrics-*-it_workspace", "logs-*-it_other", "metrics-*-it_other"]
    error_message = "Dropping a data type removes its index privileges."
  }
}

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

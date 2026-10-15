# Real provider against the throwaway stack from compose.yml: apply, check,
# destroy. Run through scripts/integration.sh (`mise run
# test:integration`), never against a real cluster.

provider "elasticstack" {
  elasticsearch {} # ELASTICSEARCH_* env vars, set by scripts/integration.sh
  kibana {}        # KIBANA_* env vars
}

variables {
  workspace = "ci_workspace"
  owner     = "ci"
  read_from = ["ci_shared"]
  access = {
    bindings = { "grp-ci-viewers" = "viewer", "grp-ci-engineers" = "editor" }
  }
  rules = {
    checkout_errors = {
      query     = { query = { match = { "service.name" = "checkout" } } }
      threshold = 5
    }
  }
}

run "onboard_workspace" {
  assert {
    condition     = output.space_id == "ci_workspace"
    error_message = "Space not created with the workspace id."
  }
  assert {
    condition     = output.data_view_ids["logs"] == "ci_workspace-logs"
    error_message = "Data view ids must be deterministic."
  }
  assert {
    condition     = length(output.rule_ids) == 3
    error_message = "Two baseline rules plus one workspace rule."
  }
  assert {
    condition     = alltrue([for r in elasticstack_kibana_import_saved_objects.baseline : r.success])
    error_message = "Baseline saved objects must import without errors."
  }
}

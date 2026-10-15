# Unit tests: mocked provider, no cluster, no credentials. `mise run test`.
mock_provider "elasticstack" {}

variables {
  workspace = "payments"
  owner     = "payments-team"
}

run "defaults_build_a_complete_workspace" {
  command = plan

  assert {
    condition     = elasticstack_kibana_space.this.space_id == "payments"
    error_message = "Space id must equal the workspace id."
  }
  assert {
    condition     = strcontains(elasticstack_kibana_space.this.description, "Owner: payments-team.")
    error_message = "The space description names the owner."
  }
  assert {
    condition     = length(elasticstack_kibana_data_view.this) == 3
    error_message = "One data view per default data type (logs, metrics, traces)."
  }
  assert {
    condition     = output.index_patterns["logs"] == "logs-*-payments" && output.namespace == "payments"
    error_message = "Index patterns follow <type>-*-<workspace>, and the namespace is the workspace id."
  }
  assert {
    condition     = elasticstack_kibana_default_data_view.this.space_id == "payments"
    error_message = "The space gets a default data view."
  }
  assert {
    condition     = length(elasticstack_kibana_security_role.this) == 2
    error_message = "viewer and editor roles always exist."
  }
  assert {
    condition     = length(elasticstack_elasticsearch_security_role_mapping.this) == 0
    error_message = "Nobody has access by default: no bindings, no mappings."
  }
  assert {
    condition     = length(elasticstack_kibana_alerting_rule.this) == 2 && length(elasticstack_kibana_action_connector.index) == 1
    error_message = "Baseline alerting: two rules and the index connector."
  }
  assert {
    condition     = elasticstack_kibana_alerting_rule.this["no_data"].rule_id == "payments-no-data"
    error_message = "Rule ids are deterministic: <workspace>-<key with dashes>."
  }
  assert {
    condition     = contains(elasticstack_kibana_alerting_rule.this["error_rate"].tags, "owner:payments-team")
    error_message = "Rules are tagged with the owner."
  }
  assert {
    condition     = length(elasticstack_kibana_import_saved_objects.baseline) >= 1
    error_message = "Baseline saved objects are installed."
  }
}

run "invalid_ids_are_rejected" {
  command = plan

  variables {
    workspace = "pay-ments"
  }

  expect_failures = [var.workspace]
}

run "default_is_not_a_workspace" {
  command = plan

  variables {
    workspace = "default"
  }

  expect_failures = [var.workspace]
}

run "owner_is_required" {
  command = plan

  variables {
    owner = " "
  }

  expect_failures = [var.owner]
}

run "logs_are_required" {
  command = plan

  variables {
    data_types = ["metrics"]
  }

  expect_failures = [var.data_types]
}

run "space_settings_are_validated" {
  command = plan

  variables {
    color    = "blue"
    solution = "observability"
  }

  expect_failures = [var.color, var.solution]
}

run "bindings_create_mappings_per_role" {
  command = plan

  variables {
    access = {
      realm = "oidc"
      bindings = {
        "grp-b" = "viewer"
        "grp-a" = "viewer"
        "grp-c" = "editor"
      }
    }
  }

  assert {
    condition     = toset(keys(elasticstack_elasticsearch_security_role_mapping.this)) == toset(["viewer", "editor"])
    error_message = "One mapping per role that has at least one group."
  }
  assert {
    condition = jsondecode(elasticstack_elasticsearch_security_role_mapping.this["viewer"].rules) == {
      all = [
        { field = { "realm.name" = "oidc" } },
        { any = [{ field = { groups = "grp-a" } }, { field = { groups = "grp-b" } }] },
      ]
    }
    error_message = "A mapping requires the realm and any of its groups (sorted)."
  }
}

run "bindings_only_to_known_roles" {
  command = plan

  variables {
    access = { bindings = { "grp-a" = "admin" } }
  }

  expect_failures = [var.access]
}

run "read_from_grants_data_not_spaces" {
  command = plan

  variables {
    data_types = ["logs"]
    read_from  = ["platform"]
  }

  assert {
    condition     = contains(local.read_patterns, "logs-*-platform") && contains(local.read_patterns, "logs-*-payments")
    error_message = "Roles read their own data and every read_from workspace's."
  }
  assert {
    condition     = one([for k in elasticstack_kibana_security_role.this["viewer"].kibana : k.spaces]) == toset(["payments"])
    error_message = "read_from never grants another workspace's space."
  }
}

run "read_from_holds_workspace_ids" {
  command = plan

  variables {
    read_from = ["default"]
  }

  expect_failures = [var.read_from]
}

run "workspace_rules_join_the_baseline" {
  command = plan

  variables {
    rules = {
      checkout_errors = {
        query     = { query = { match = { "service.name" = "checkout" } } }
        threshold = 10
      }
    }
  }

  assert {
    condition     = length(elasticstack_kibana_alerting_rule.this) == 3
    error_message = "Workspace rules are added next to the two baseline rules."
  }
  assert {
    condition     = elasticstack_kibana_alerting_rule.this["checkout_errors"].name == "[Payments] checkout_errors"
    error_message = "Unnamed rules get a [display name] prefix."
  }
  assert {
    condition     = jsondecode(elasticstack_kibana_alerting_rule.this["checkout_errors"].params).index == ["logs-*-payments"]
    error_message = "Workspace rules only query the workspace's own data."
  }
}

run "destinations_notify_every_rule" {
  command = plan

  variables {
    alerting = {
      destinations = [{ connector_id = "servicenow-preconfigured", params = { subAction = "pushToService" } }]
    }
  }

  assert {
    condition     = output.connector_ids[1] == "servicenow-preconfigured" && length(output.connector_ids) == 2
    error_message = "Destinations follow the index connector."
  }
  assert {
    condition     = length(elasticstack_kibana_alerting_rule.this["error_rate"].actions) == 2
    error_message = "Every rule notifies every destination."
  }
}

run "alerting_can_be_disabled" {
  command = plan

  variables {
    alerting = { enabled = false }
    rules    = { ignored = { query = {}, threshold = 1 } }
  }

  assert {
    condition     = length(elasticstack_kibana_alerting_rule.this) == 0 && length(elasticstack_kibana_action_connector.index) == 0
    error_message = "alerting.enabled = false creates no rules and no connector."
  }
}

run "reserved_rule_keys_are_rejected" {
  command = plan

  variables {
    rules = { no_data = { query = {}, threshold = 1 } }
  }

  expect_failures = [var.rules]
}

run "rules_on_missing_data_type_fail" {
  command = plan

  variables {
    data_types = ["logs"]
    rules      = { slow_traces = { data_type = "traces", query = {}, threshold = 1 } }
  }

  expect_failures = [elasticstack_kibana_alerting_rule.this["slow_traces"]]
}

run "baseline_can_be_excluded_and_extras_added" {
  command = plan

  variables {
    exclude_baseline_saved_objects = ["errors"]
    extra_saved_objects            = { custom = "{}" }
  }

  assert {
    condition     = !contains(keys(elasticstack_kibana_import_saved_objects.baseline), "errors")
    error_message = "Excluded baseline objects aren't installed."
  }
  assert {
    condition     = contains(keys(elasticstack_kibana_import_saved_objects.extra), "custom")
    error_message = "Extras are installed under their key."
  }
}

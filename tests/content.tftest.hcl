# Unit tests for content and alerting: plans against a mocked provider.

mock_provider "elasticstack" {}

variables {
  workspace_id = "otel_demo"
  display_name = "OTel demo"
}

run "baseline_by_default" {
  command = plan

  assert {
    condition     = keys(elasticstack_kibana_import_saved_objects.baseline) == ["overview"]
    error_message = "The baseline templates are imported."
  }

  assert {
    condition     = strcontains(elasticstack_kibana_import_saved_objects.baseline["overview"].file_contents, "\"id\":\"otel_demo-baseline-overview\"") && !strcontains(elasticstack_kibana_import_saved_objects.baseline["overview"].file_contents, "$${workspace_id}")
    error_message = "Templates render with the workspace id, and nothing is left unrendered."
  }

  assert {
    condition     = toset(keys(elasticstack_kibana_alerting_rule.this)) == toset(["baseline_no_data", "baseline_error_rate"])
    error_message = "Both baseline rules exist by default."
  }

  assert {
    condition     = elasticstack_kibana_alerting_rule.this["baseline_no_data"].rule_id == "otel_demo-baseline_no_data"
    error_message = "Rule ids are <id>-<key>."
  }

  assert {
    condition     = jsondecode(elasticstack_kibana_alerting_rule.this["baseline_no_data"].params).index == ["logs-*-otel_demo", "metrics-*-otel_demo", "traces-*-otel_demo"]
    error_message = "No data watches every own data type, and only the workspace's namespace."
  }

  assert {
    condition     = jsondecode(elasticstack_kibana_alerting_rule.this["baseline_error_rate"].params).searchConfiguration.index == "otel_demo-logs"
    error_message = "Error rate reads the workspace's logs data view."
  }

  assert {
    condition     = alltrue([for r in elasticstack_kibana_alerting_rule.this : contains(r.tags, "workspace:otel_demo")])
    error_message = "Every rule is tagged with its workspace."
  }

  assert {
    condition     = alltrue([for r in elasticstack_kibana_alerting_rule.this : length(r.actions) == 0])
    error_message = "No alert_actions, no actions."
  }
}

run "no_logs_no_log_content" {
  command = plan

  variables {
    data_types        = ["metrics"]
    default_data_type = "metrics"
  }

  assert {
    condition     = length(elasticstack_kibana_import_saved_objects.baseline) == 0
    error_message = "The baseline content is about logs: none without them."
  }

  assert {
    condition     = keys(elasticstack_kibana_alerting_rule.this) == ["baseline_no_data"]
    error_message = "Without logs, only the no data rule."
  }
}

run "baseline_off" {
  command = plan

  variables {
    baseline_content = false
    baseline_rules   = { no_data = false, error_rate = false }
  }

  assert {
    condition     = length(elasticstack_kibana_import_saved_objects.baseline) == 0 && length(elasticstack_kibana_alerting_rule.this) == 0
    error_message = "The baseline can be switched off."
  }
}

run "workspace_saved_objects_drop_data_views" {
  command = plan

  variables {
    saved_objects = {
      "dashboards/latency.ndjson" = <<-EOT
        {"type":"index-pattern","id":"otel_demo-logs","attributes":{"title":"logs-*-otel_demo"},"references":[]}
        {"type":"dashboard","id":"otel_demo-latency","attributes":{"title":"Latency"},"references":[]}

        {"exportedCount":2,"missingRefCount":0,"missingReferences":[]}
      EOT
    }
  }

  assert {
    condition     = elasticstack_kibana_import_saved_objects.workspace["dashboards/latency.ndjson"].file_contents == "{\"type\":\"dashboard\",\"id\":\"otel_demo-latency\",\"attributes\":{\"title\":\"Latency\"},\"references\":[]}"
    error_message = "Only the dashboard is imported: no data view, no summary, no blank line."
  }
}

run "actions_and_workspace_rules" {
  command = plan

  variables {
    connectors = {
      log = { type = ".server-log" }
    }
    alert_actions = [
      { connector = "log", params = "{\"level\":\"warn\",\"message\":\"{{rule.name}}\"}" },
      { connector_id = "homelab-email", params = "{\"to\":[\"sre@example.org\"],\"subject\":\"{{rule.name}}\"}" },
    ]
    rules = {
      checkout_latency = {
        name         = "Checkout latency"
        rule_type_id = ".es-query"
        params       = jsonencode({ searchType = "esQuery", index = ["logs-*-otel_demo"], timeField = "@timestamp", esQuery = "{\"query\":{\"match_all\":{}}}", size = 0, threshold = [1], thresholdComparator = ">", timeWindowSize = 5, timeWindowUnit = "m" })
        tags         = ["checkout"]
      }
      quiet = {
        name         = "Informational"
        rule_type_id = ".es-query"
        params       = jsonencode({ searchType = "esQuery", index = ["logs-*-otel_demo"], timeField = "@timestamp", esQuery = "{\"query\":{\"match_all\":{}}}", size = 0, threshold = [1], thresholdComparator = ">", timeWindowSize = 5, timeWindowUnit = "m" })
        notify       = false
      }
    }
  }

  assert {
    condition     = length(elasticstack_kibana_alerting_rule.this["baseline_no_data"].actions) == 2 && length(elasticstack_kibana_alerting_rule.this["checkout_latency"].actions) == 2
    error_message = "Baseline and workspace rules send to every alert action."
  }

  assert {
    condition     = length(elasticstack_kibana_alerting_rule.this["quiet"].actions) == 0
    error_message = "notify = false sends nothing."
  }

  assert {
    condition     = elasticstack_kibana_alerting_rule.this["checkout_latency"].tags == toset(["checkout", "workspace:otel_demo"]) && elasticstack_kibana_alerting_rule.this["checkout_latency"].consumer == "alerts"
    error_message = "Workspace rules keep their tags, gain the workspace's, and default to the alerts consumer."
  }

  assert {
    condition = (
      elasticstack_kibana_alerting_rule.this["baseline_no_data"].actions[0].group == "query matched" &&
      elasticstack_kibana_alerting_rule.this["baseline_error_rate"].actions[0].group == "custom_threshold.fired"
    )
    error_message = "Actions use the rule type's default action group, never \"default\"."
  }

  assert {
    condition     = elasticstack_kibana_alerting_rule.this["baseline_no_data"].actions[1].id == "homelab-email"
    error_message = "A connector_id is used as is."
  }

  assert {
    condition     = elasticstack_kibana_action_connector.this["log"].name == "log" && elasticstack_kibana_action_connector.this["log"].space_id == "otel_demo"
    error_message = "Connectors live in the workspace's space, named by key unless named."
  }
}

run "rejects_action_with_both_targets" {
  command = plan

  variables {
    alert_actions = [{ connector = "log", connector_id = "x", params = "{}" }]
  }

  expect_failures = [var.alert_actions]
}

run "rejects_baseline_prefixed_rule_key" {
  command = plan

  variables {
    rules = {
      baseline_mine = { name = "x", rule_type_id = ".es-query", params = "{\"size\":0}" }
    }
  }

  expect_failures = [var.rules]
}

run "rejects_notifying_rule_of_unknown_type" {
  command = plan

  variables {
    alert_actions = [{ connector_id = "homelab-email", params = "{}" }]
    rules = {
      burn = { name = "Custom", rule_type_id = "example.custom", params = "{}" }
    }
  }

  expect_failures = [elasticstack_kibana_alerting_rule.this["burn"]]
}

run "unknown_type_with_action_group" {
  command = plan

  variables {
    alert_actions = [{ connector_id = "homelab-email", params = "{}" }]
    rules = {
      burn = { name = "Custom", rule_type_id = "example.custom", params = "{}", action_group = "example.fired" }
    }
  }

  assert {
    condition     = elasticstack_kibana_alerting_rule.this["burn"].actions[0].group == "example.fired"
    error_message = "action_group is used for a type the module doesn't know."
  }
}

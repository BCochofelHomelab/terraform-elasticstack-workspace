# Unit tests: plans against a mocked provider. No cluster, no credentials.
#   tofu init -backend=false && tofu test

mock_provider "elasticstack" {}

variables {
  workspace_id = "otel_demo"
  display_name = "OTel demo"
}

run "defaults" {
  command = plan

  assert {
    condition     = elasticstack_kibana_space.this.space_id == "otel_demo" && elasticstack_kibana_space.this.solution == "oblt"
    error_message = "The space id is the workspace id, in the Observability solution view."
  }

  assert {
    condition = output.data_view_ids == {
      logs    = "otel_demo-logs"
      metrics = "otel_demo-metrics"
      traces  = "otel_demo-traces"
    }
    error_message = "One data view per default type, with deterministic ids."
  }

  assert {
    condition     = elasticstack_kibana_data_view.this["traces"].data_view.title == "traces-*-otel_demo"
    error_message = "A data view selects <type>-*-<id>."
  }

  assert {
    condition     = output.default_data_view_id == "otel_demo-logs"
    error_message = "logs is the default data view."
  }

  assert {
    condition     = output.role_names == { viewer = "workspace-otel_demo-viewer", editor = "workspace-otel_demo-editor" }
    error_message = "Role names are workspace-<id>-<kind>."
  }

  assert {
    condition     = output.index_patterns == ["logs-*-otel_demo", "metrics-*-otel_demo", "traces-*-otel_demo"]
    error_message = "Roles read the workspace's own namespace only."
  }

  assert {
    condition     = length(elasticstack_elasticsearch_security_role_mapping.this) == 0
    error_message = "No groups, no role mapping: nobody has access by default."
  }

  assert {
    condition = alltrue([
      for r in elasticstack_kibana_security_role.this : one(r.kibana).spaces == toset(["otel_demo"])
    ])
    error_message = "Both roles are scoped to the workspace's space only."
  }

  assert {
    condition = (
      one(elasticstack_kibana_security_role.this["viewer"].kibana).base == toset(["read"]) &&
      one(elasticstack_kibana_security_role.this["editor"].kibana).base == toset(["all"])
    )
    error_message = "viewer reads the space, editor has all of it."
  }
}

run "read_from" {
  command = plan

  variables {
    data_types = ["logs"]
    read_from  = ["platform"]
  }

  assert {
    condition     = output.data_view_ids == { logs = "otel_demo-logs", "logs/platform" = "otel_demo-logs-from-platform" }
    error_message = "read_from adds one data view per type and source workspace."
  }

  assert {
    condition     = elasticstack_kibana_data_view.this["logs/platform"].data_view.title == "logs-*-platform"
    error_message = "A read_from data view selects the other workspace's namespace."
  }

  assert {
    condition     = output.index_patterns == ["logs-*-otel_demo", "logs-*-platform"]
    error_message = "read_from grants read on the other namespace."
  }
}

run "bindings_without_realm" {
  command = plan

  variables {
    access = {
      viewer_groups = ["otel-demo-viewers"]
    }
  }

  assert {
    condition     = keys(elasticstack_elasticsearch_security_role_mapping.this) == ["viewer"]
    error_message = "Only kinds with groups get a role mapping."
  }

  assert {
    condition     = jsondecode(elasticstack_elasticsearch_security_role_mapping.this["viewer"].rules) == { field = { groups = ["otel-demo-viewers"] } }
    error_message = "Without a realm, the rule matches the groups only."
  }

  assert {
    condition     = elasticstack_elasticsearch_security_role_mapping.this["viewer"].roles == toset(["workspace-otel_demo-viewer"])
    error_message = "The mapping grants the workspace's viewer role."
  }
}

run "bindings_with_realm" {
  command = plan

  variables {
    access = {
      realm         = "oidc1"
      viewer_groups = ["b", "a"]
      editor_groups = ["sre"]
    }
  }

  assert {
    condition = jsondecode(elasticstack_elasticsearch_security_role_mapping.this["viewer"].rules) == {
      all = [
        { field = { "realm.name" = "oidc1" } },
        { field = { groups = ["a", "b"] } },
      ]
    }
    error_message = "With a realm, the rule needs both the realm and a group."
  }

  assert {
    condition     = output.role_mapping_names == { viewer = "workspace-otel_demo-viewer", editor = "workspace-otel_demo-editor" }
    error_message = "One mapping per kind with groups."
  }
}

run "rejects_default_id" {
  command = plan

  variables {
    workspace_id = "default"
  }

  expect_failures = [var.workspace_id]
}

run "rejects_hyphen_in_id" {
  command = plan

  variables {
    workspace_id = "otel-demo"
  }

  expect_failures = [var.workspace_id]
}

run "rejects_unknown_data_type" {
  command = plan

  variables {
    data_types = ["logs", "events"]
  }

  expect_failures = [var.data_types]
}

run "rejects_default_type_not_in_data_types" {
  command = plan

  variables {
    data_types        = ["metrics"]
    default_data_type = "logs"
  }

  expect_failures = [elasticstack_kibana_default_data_view.this]
}

run "rejects_reading_from_itself" {
  command = plan

  variables {
    read_from = ["otel_demo"]
  }

  expect_failures = [elasticstack_kibana_space.this]
}

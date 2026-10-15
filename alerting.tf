# Baseline and workspace rules are Elasticsearch query rules (available on
# every license tier). Each notifies the workspace's index connector and
# every destination the caller passes in.

locals {
  alerts_index    = "alerts-workspace-${var.workspace}"
  index_connector = var.alerting.enabled && var.alerting.index_connector

  tags = ["workspace:${var.workspace}", "owner:${var.owner}", "managed-by:opentofu"]

  # Every rule has the same shape (query already JSON), so baseline and
  # workspace rules merge into one map without type conflicts.
  baseline_rules = {
    error_rate = {
      name       = "[${local.name}] Error rate"
      data_type  = "logs"
      query      = jsonencode({ query = { bool = { filter = [{ match_phrase = { "log.level" = "error" } }] } } })
      comparator = ">"
      threshold  = var.alerting.error_threshold
      window     = var.alerting.error_window_minutes
    }
    no_data = {
      name       = "[${local.name}] No data"
      data_type  = "logs"
      query      = jsonencode({ query = { match_all = {} } })
      comparator = "<"
      threshold  = 1
      window     = var.alerting.no_data_window_minutes
    }
  }

  workspace_rules = {
    for k, r in var.rules : k => {
      name       = coalesce(r.name, "[${local.name}] ${k}")
      data_type  = r.data_type
      query      = jsonencode(r.query)
      comparator = r.comparator
      threshold  = r.threshold
      window     = r.window_minutes
    }
  }

  rules = { for k, r in merge(local.baseline_rules, local.workspace_rules) : k => r if var.alerting.enabled }

  # Deterministic connector id: the provider requires a UUID.
  index_connector_id = uuidv5("url", "https://workspace.invalid/${var.workspace}/connectors/alerts-index")

  actions = concat(
    local.index_connector ? [{
      connector_id = local.index_connector_id
      params = {
        documents = [{
          "@timestamp"   = "{{date}}"
          workspace      = var.workspace
          rule           = "{{rule.name}}"
          alert          = "{{alert.id}}"
          context_title  = "{{context.title}}"
          context_detail = "{{context.message}}"
        }]
      }
    }] : [],
    var.alerting.destinations,
  )
}

resource "elasticstack_kibana_action_connector" "index" {
  count = local.index_connector ? 1 : 0

  connector_id      = local.index_connector_id
  name              = "workspace-${var.workspace}-alerts-index"
  space_id          = elasticstack_kibana_space.this.space_id
  connector_type_id = ".index"
  config = jsonencode({
    index              = local.alerts_index
    refresh            = false
    executionTimeField = "@timestamp"
  })
}

resource "elasticstack_kibana_alerting_rule" "this" {
  for_each = local.rules

  # Any string works as rule_id from Kibana 8.17: deterministic ids make
  # rules addressable and importable by name.
  rule_id      = "${var.workspace}-${replace(each.key, "_", "-")}"
  name         = each.value.name
  space_id     = elasticstack_kibana_space.this.space_id
  consumer     = "stackAlerts"
  rule_type_id = ".es-query"
  interval     = var.alerting.interval
  enabled      = true
  tags         = local.tags

  params = jsonencode({
    searchType          = "esQuery"
    esQuery             = each.value.query
    index               = [local.index_patterns[each.value.data_type]]
    timeField           = "@timestamp"
    threshold           = [each.value.threshold]
    thresholdComparator = each.value.comparator
    size                = 0
    timeWindowSize      = each.value.window
    timeWindowUnit      = "m"
  })

  dynamic "actions" {
    for_each = local.actions
    content {
      id     = actions.value.connector_id
      group  = "query matched"
      params = jsonencode(actions.value.params)

      frequency {
        notify_when = "onActionGroupChange"
        summary     = false
      }
    }
  }

  lifecycle {
    precondition {
      condition     = contains(var.data_types, each.value.data_type)
      error_message = "Rule ${each.key} queries data_type ${each.value.data_type}, which isn't in var.data_types."
    }
  }

  depends_on = [elasticstack_kibana_action_connector.index]
}

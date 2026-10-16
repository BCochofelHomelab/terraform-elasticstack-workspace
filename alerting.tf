# Alerting: connectors without secrets, the baseline rules (no data, error
# rate) and the workspace's own rules, all sending to alert_actions.

locals {
  own_patterns = [for t in var.data_types : "${t}-*-${local.id}"]

  actions = [
    for a in var.alert_actions : {
      id     = a.connector != null ? elasticstack_kibana_action_connector.this[a.connector].connector_id : a.connector_id
      params = a.params
    }
  ]

  baseline_rules = merge(
    var.baseline_rules.no_data ? {
      baseline_no_data = {
        name         = "No data"
        rule_type_id = ".es-query"
        consumer     = "alerts"
        interval     = "5m"
        params = jsonencode({
          searchType                 = "esQuery"
          index                      = local.own_patterns
          timeField                  = "@timestamp"
          esQuery                    = jsonencode({ query = { match_all = {} } })
          size                       = 0
          aggType                    = "count"
          groupBy                    = "all"
          threshold                  = [1]
          thresholdComparator        = "<"
          timeWindowSize             = var.baseline_rules.no_data_minutes
          timeWindowUnit             = "m"
          excludeHitsFromPreviousRun = false
        })
        enabled = true
        tags    = ["baseline"]
        notify  = true
      }
    } : {},
    var.baseline_rules.error_rate && contains(var.data_types, "logs") ? {
      baseline_error_rate = {
        name         = "Error rate"
        rule_type_id = "observability.rules.custom_threshold"
        consumer     = "alerts"
        interval     = "1m"
        params = jsonencode({
          criteria = [{
            comparator = ">"
            threshold  = [var.baseline_rules.error_rate_percent]
            timeSize   = 5
            timeUnit   = "m"
            metrics = [
              { name = "A", aggType = "count", filter = var.baseline_rules.error_filter },
              { name = "B", aggType = "count" },
            ]
            equation = "A / B * 100"
            label    = "Error rate (%)"
          }]
          groupBy               = ["service.name"]
          alertOnNoData         = false
          alertOnGroupDisappear = false
          searchConfiguration = {
            index = elasticstack_kibana_data_view.this["logs"].data_view.id
            query = { query = "", language = "kuery" }
          }
        })
        enabled = true
        tags    = ["baseline"]
        notify  = true
      }
    } : {},
  )

  rules = merge(local.baseline_rules, var.rules)

  # Each rule type's default action group, which an action must name (the
  # provider would send "default", which these types reject). Read from
  # Kibana 9.5.4's GET /api/alerting/rule_types (default_action_group_id).
  # A rule of another type sets action_group.
  default_action_groups = {
    ".es-query"                            = "query matched"
    ".index-threshold"                     = "threshold met"
    "apm.anomaly"                          = "threshold_met"
    "apm.error_rate"                       = "threshold_met"
    "apm.transaction_duration"             = "threshold_met"
    "apm.transaction_error_rate"           = "threshold_met"
    "logs.alert.document.count"            = "logs.threshold.fired"
    "metrics.alert.inventory.threshold"    = "metrics.inventory_threshold.fired"
    "metrics.alert.threshold"              = "metrics.threshold.fired"
    "observability.rules.custom_threshold" = "custom_threshold.fired"
  }
  action_groups = {
    for k, r in local.rules : k => coalesce(try(r.action_group, null), lookup(local.default_action_groups, r.rule_type_id, null), "unknown")
  }
}

resource "elasticstack_kibana_action_connector" "this" {
  for_each = var.connectors

  space_id          = elasticstack_kibana_space.this.space_id
  name              = coalesce(each.value.name, each.key)
  connector_type_id = each.value.type
  config            = each.value.config
}

resource "elasticstack_kibana_alerting_rule" "this" {
  for_each = local.rules

  space_id     = elasticstack_kibana_space.this.space_id
  rule_id      = "${local.id}-${each.key}"
  name         = each.value.name
  rule_type_id = each.value.rule_type_id
  consumer     = each.value.consumer
  interval     = each.value.interval
  params       = each.value.params
  enabled      = each.value.enabled
  tags         = setunion(each.value.tags, ["workspace:${local.id}"])

  lifecycle {
    precondition {
      condition     = !(each.value.notify && length(local.actions) > 0) || local.action_groups[each.key] != "unknown"
      error_message = "Rule \"${each.key}\" (${each.value.rule_type_id}) sends alerts, but the module doesn't know its rule type's action group: set action_group (GET /api/alerting/rule_types lists default_action_group_id)."
    }
  }

  dynamic "actions" {
    for_each = each.value.notify ? local.actions : []

    content {
      id     = actions.value.id
      group  = local.action_groups[each.key]
      params = actions.value.params

      frequency {
        summary     = false
        notify_when = "onActionGroupChange"
      }
    }
  }
}

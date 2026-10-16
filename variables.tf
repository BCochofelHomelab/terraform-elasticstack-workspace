variable "workspace_id" {
  description = "The workspace's permanent id. It is the Kibana space id and the data stream namespace (`<type>-<dataset>-<id>`), so only `a-z`, `0-9` and `_`, and never `default`. Changing it replaces everything."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9_]{1,64}$", var.workspace_id)) && var.workspace_id != "default"
    error_message = "workspace_id must match ^[a-z0-9_]{1,64}$ and must not be \"default\"."
  }
}

variable "display_name" {
  description = "The space's display name in Kibana. Can change at any time."
  type        = string

  validation {
    condition     = length(trimspace(var.display_name)) > 0
    error_message = "display_name must not be empty."
  }
}

variable "description" {
  description = "The space's description: who owns the workspace and what it observes."
  type        = string
  default     = null
}

variable "color" {
  description = "The space avatar's colour, as `#rrggbb`. Kibana picks one from the name when null."
  type        = string
  default     = null

  validation {
    condition     = var.color == null || can(regex("^#[0-9A-Fa-f]{6}$", var.color))
    error_message = "color must be a hex colour like #1EA593."
  }
}

variable "initials" {
  description = "One or two characters for the space avatar. Kibana derives them from the name when null."
  type        = string
  default     = null

  validation {
    condition     = var.initials == null || can(regex("^.{1,2}$", var.initials))
    error_message = "initials must be 1 or 2 characters."
  }
}

variable "solution" {
  description = "The space's solution view: `oblt` (Observability), `classic`, `es` or `security`."
  type        = string
  default     = "oblt"
  nullable    = false

  validation {
    condition     = contains(["oblt", "classic", "es", "security"], var.solution)
    error_message = "solution must be one of oblt, classic, es, security."
  }
}

variable "disabled_features" {
  description = "Kibana feature ids hidden in the space (the Features API lists them). Null leaves it to Kibana and the solution view."
  type        = set(string)
  default     = null
}

variable "data_types" {
  description = "The data stream types the workspace has: one data view `<type>-*-<id>` per type, and index privileges on the same patterns."
  type        = list(string)
  default     = ["logs", "metrics", "traces"]
  nullable    = false

  validation {
    condition     = length(var.data_types) > 0 && alltrue([for t in var.data_types : contains(["logs", "metrics", "traces", "synthetics", "profiling"], t)])
    error_message = "data_types must be a non-empty list of: logs, metrics, traces, synthetics, profiling."
  }

  validation {
    condition     = length(distinct(var.data_types)) == length(var.data_types)
    error_message = "data_types must not repeat a type."
  }
}

variable "default_data_type" {
  description = "The data type whose data view is the space's default. Must be in data_types."
  type        = string
  default     = "logs"
  nullable    = false
}

variable "read_from" {
  description = "Other workspaces whose data this one may read. The data's owner approves each entry. Adds index privileges and a data view `<type>-*-<other>` per data type."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for w in var.read_from : can(regex("^[a-z0-9_]{1,64}$", w)) && w != "default"])
    error_message = "Every read_from entry must be a workspace id: ^[a-z0-9_]{1,64}$, not \"default\"."
  }
}

variable "access" {
  description = <<-EOT
    Who gets the workspace's roles, through role mappings. Groups match the
    user's `groups` (an OIDC or SAML claim, LDAP groups); `realm`, when set,
    limits the mappings to that realm. No groups, no mapping: nobody has
    access by default. Native users are given the role names (outputs)
    directly.
  EOT
  type = object({
    realm         = optional(string)
    viewer_groups = optional(set(string), [])
    editor_groups = optional(set(string), [])
  })
  default  = {}
  nullable = false
}

# --- Content -----------------------------------------------------------------

variable "baseline_content" {
  description = "Import the baseline saved objects (templates/saved-objects: an Overview dashboard with a service.name selector, Logs and Errors). Needs `logs` in data_types."
  type        = bool
  default     = true
  nullable    = false
}

variable "saved_objects" {
  description = "The workspace's own content, by name: Kibana exports (.ndjson) from this workspace's space, e.g. `{ for f in fileset(...) : f => file(...) }`. Data views in them are dropped: the module owns those. Removing an entry stops managing its objects; it doesn't delete them from Kibana."
  type        = map(string)
  default     = {}
  nullable    = false
}

# --- Alerting ----------------------------------------------------------------

variable "connectors" {
  description = <<-EOT
    Connectors created in the workspace's space, by key, for alert_actions
    to reference. Only connectors without secrets (`.server-log`, `.index`,
    an unauthenticated `.webhook`): `config` is the type's JSON. One that
    needs secrets is preconfigured in kibana.yml (available in every space)
    and referenced by `connector_id`, so no secret passes through a
    workspace's state.
  EOT
  type = map(object({
    type   = string
    name   = optional(string)
    config = optional(string)
  }))
  default  = {}
  nullable = false
}

variable "alert_actions" {
  description = <<-EOT
    Where the workspace's rules send alerts: the default alert destination.
    Each entry names one connector, by `connector` (a key of connectors) or
    `connector_id` (preconfigured, or created elsewhere in the space), with
    the action's `params` as JSON, which depend on the connector type.
    Params apply to every rule: `{{rule.name}}` works everywhere;
    `{{context.reason}}` (threshold rules) and `{{context.message}}` (ES
    query rules) render empty where they don't exist, so use both.
  EOT
  type = list(object({
    connector    = optional(string)
    connector_id = optional(string)
    params       = string
  }))
  default  = []
  nullable = false

  validation {
    condition     = alltrue([for a in var.alert_actions : (a.connector == null) != (a.connector_id == null)])
    error_message = "Each alert action sets exactly one of connector or connector_id."
  }
}

variable "baseline_rules" {
  description = <<-EOT
    The baseline rules, both on by default and both sent to alert_actions:
    `no_data` fires when none of the workspace's data arrived in
    `no_data_minutes`; `error_rate` (needs `logs`) fires per service.name
    when more than `error_rate_percent` of its log lines in 5 minutes match
    `error_filter` (KQL).
  EOT
  type = object({
    no_data            = optional(bool, true)
    no_data_minutes    = optional(number, 15)
    error_rate         = optional(bool, true)
    error_rate_percent = optional(number, 5)
    error_filter       = optional(string, "log.level: (error or ERROR)")
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.baseline_rules.no_data_minutes >= 1 && var.baseline_rules.error_rate_percent > 0 && var.baseline_rules.error_rate_percent <= 100
    error_message = "no_data_minutes must be at least 1, and error_rate_percent in (0, 100]."
  }
}

variable "rules" {
  description = <<-EOT
    The workspace's own alerting rules, by key (`[a-z0-9_]`; the rule id is
    `<id>-<key>`). `params` is the rule type's JSON. With `notify` (the
    default) they send to alert_actions like the baseline rules, in the rule
    type's default action group; a type the module doesn't know needs
    `action_group`. Every rule is tagged `workspace:<id>`.
  EOT
  type = map(object({
    name         = string
    rule_type_id = string
    consumer     = optional(string, "alerts")
    interval     = optional(string, "1m")
    params       = string
    enabled      = optional(bool, true)
    tags         = optional(set(string), [])
    notify       = optional(bool, true)
    action_group = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for k in keys(var.rules) : can(regex("^[a-z0-9_]{1,64}$", k)) && !startswith(k, "baseline")])
    error_message = "Rule keys match ^[a-z0-9_]{1,64}$ and don't start with \"baseline\" (the baseline rules' prefix)."
  }
}

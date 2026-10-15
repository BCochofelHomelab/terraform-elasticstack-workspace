variable "workspace" {
  description = <<-EOT
    Workspace id: permanent, and baked into data stream names as the
    namespace (`<type>-<dataset>-<workspace>`), the Kibana space id, data view
    ids and role names. Name it after what is observed, not after a team.
    Lowercase letters, digits and underscores (namespaces can't contain
    hyphens), and never `default`.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9_]{1,64}$", var.workspace)) && var.workspace != "default"
    error_message = "workspace must match ^[a-z0-9_]{1,64}$ and can't be \"default\"."
  }
}

variable "owner" {
  description = "The one accountable owner (a team or a person's role, not a group of teams). Shown in the space description and tagged on every rule."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner can't be empty: every workspace has one accountable owner."
  }
}

variable "display_name" {
  description = "Space display name. Can change at any time, unlike the id. Defaults to the id in title case."
  type        = string
  default     = null
}

variable "description" {
  description = "What the workspace observes, in one sentence."
  type        = string
  default     = null
}

variable "color" {
  description = "Space avatar colour, as #RRGGBB. Null lets Kibana derive one from the name."
  type        = string
  default     = null

  validation {
    condition     = var.color == null ? true : can(regex("^#[0-9A-Fa-f]{6}$", var.color))
    error_message = "color must be #RRGGBB."
  }
}

variable "solution" {
  description = "Kibana solution view for the space: oblt, es, security or classic. Null keeps Kibana's default. Needs a Kibana that supports solution views."
  type        = string
  default     = null

  validation {
    condition     = var.solution == null ? true : contains(["oblt", "es", "security", "classic"], var.solution)
    error_message = "solution must be oblt, es, security or classic."
  }
}

variable "disabled_features" {
  description = "Kibana feature ids hidden in the space (the Features API lists them)."
  type        = set(string)
  default     = []
  nullable    = false
}

variable "data_types" {
  description = "Data stream types the workspace receives: one data view each. Must include \"logs\": the baseline content and rules use it."
  type        = set(string)
  default     = ["logs", "metrics", "traces"]
  nullable    = false

  validation {
    condition     = contains(var.data_types, "logs") && length(setsubtract(var.data_types, ["logs", "metrics", "traces"])) == 0
    error_message = "data_types must include \"logs\" and only contain logs, metrics or traces."
  }
}

variable "access" {
  description = <<-EOT
    Who gets into the workspace. Roles workspace-<id>-viewer and
    workspace-<id>-editor always exist; `bindings` maps an identity-provider
    group to one of them (the group's membership is managed in the identity
    provider, not here). `realm` limits the mappings to one realm, e.g. the
    OIDC realm. No bindings means nobody has access by default.
  EOT
  type = object({
    realm    = optional(string)
    bindings = optional(map(string), {})
  })
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for role in values(var.access.bindings) : contains(["viewer", "editor"], role)])
    error_message = "Each binding maps a group to \"viewer\" or \"editor\"."
  }
}

variable "read_from" {
  description = <<-EOT
    Other workspaces whose data this workspace's roles may read, e.g. a shared
    platform workspace. Grants read on their data streams only, not their
    spaces. The owner of the data being read approves the grant (in the
    platform repo, through CODEOWNERS).
  EOT
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for w in var.read_from : can(regex("^[a-z0-9_]{1,64}$", w)) && w != "default"])
    error_message = "read_from holds workspace ids: ^[a-z0-9_]{1,64}$, never \"default\"."
  }
}

variable "exclude_baseline_saved_objects" {
  description = "Baseline saved-object templates (file names in templates/saved-objects, without extension) not to install in this workspace."
  type        = set(string)
  default     = []
  nullable    = false
}

variable "extra_saved_objects" {
  description = <<-EOT
    The workspace's own saved objects (dashboards, searches, visualizations)
    as NDJSON contents, keyed by a stable name. Typically every *.ndjson
    file in the workspace's dashboards/ folder, keyed by file name.
  EOT
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "alerting" {
  description = <<-EOT
    Baseline alerting. `index_connector` writes every alert to
    alerts-workspace-<id> (works on the basic license). `destinations` are
    existing connectors (e.g. a ServiceNow or email connector, preconfigured
    or managed in the platform repo) that every rule notifies, each with its
    action params. The first destination is the workspace's default alert
    destination.
  EOT
  type = object({
    enabled         = optional(bool, true)
    index_connector = optional(bool, true)
    destinations = optional(list(object({
      connector_id = string
      params       = any
    })), [])
    interval               = optional(string, "5m")
    error_threshold        = optional(number, 50)
    error_window_minutes   = optional(number, 5)
    no_data_window_minutes = optional(number, 15)
  })
  default  = {}
  nullable = false
}

variable "rules" {
  description = <<-EOT
    The workspace's own Elasticsearch query rules, keyed by a stable name.
    Each queries only this workspace's data of `data_type` and notifies the
    same destinations as the baseline rules. `query` is a raw Elasticsearch
    query object, e.g. { query = { match = { "service.name" = "checkout" } } }.
  EOT
  type = map(object({
    name           = optional(string)
    data_type      = optional(string, "logs")
    query          = any
    comparator     = optional(string, ">")
    threshold      = number
    window_minutes = optional(number, 5)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = length(setintersection(keys(var.rules), ["error_rate", "no_data"])) == 0
    error_message = "Rule keys error_rate and no_data are reserved for the baseline rules."
  }

  validation {
    condition     = alltrue([for r in values(var.rules) : contains([">", ">=", "<", "<="], r.comparator)])
    error_message = "comparator must be one of >, >=, <, <=."
  }

  validation {
    condition     = alltrue([for k in keys(var.rules) : can(regex("^[a-z0-9_]{1,64}$", k))])
    error_message = "Rule keys are lowercase letters, digits and underscores: they become part of the rule id."
  }
}

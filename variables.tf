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

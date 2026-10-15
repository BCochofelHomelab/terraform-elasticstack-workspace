# Workspace: one id in, a ready-to-use observability space out. Works on
# self-managed clusters and Elastic Cloud alike (elasticstack provider only).
# The caller configures the provider.

locals {
  name = coalesce(var.display_name, title(replace(var.workspace, "_", " ")))

  # Namespace = workspace id: every data stream of this workspace matches
  # <type>-*-<id>. That convention is the module's only contract with the
  # platform (agent policies, APM, Logstash set the namespace).
  index_patterns = { for t in var.data_types : t => "${t}-*-${var.workspace}" }
  data_view_ids  = { for t in var.data_types : t => "${var.workspace}-${t}" }

  description = join(" ", compact([
    var.description,
    "Owner: ${var.owner}.",
  ]))
}

resource "elasticstack_kibana_space" "this" {
  space_id          = var.workspace
  name              = local.name
  description       = local.description
  color             = var.color
  solution          = var.solution
  disabled_features = var.disabled_features
}

resource "elasticstack_kibana_data_view" "this" {
  for_each = local.index_patterns

  space_id = elasticstack_kibana_space.this.space_id
  override = true

  data_view = {
    id              = local.data_view_ids[each.key]
    name            = "${title(each.key)} (${local.name})"
    title           = each.value
    time_field_name = "@timestamp"
    # A new workspace has no data yet; the view must exist anyway.
    allow_no_index = true
  }
}

# Logs open by default in Discover.
resource "elasticstack_kibana_default_data_view" "this" {
  space_id     = elasticstack_kibana_space.this.space_id
  data_view_id = elasticstack_kibana_data_view.this["logs"].data_view.id
  force        = true
  # The space goes away on destroy anyway.
  skip_delete = true
}

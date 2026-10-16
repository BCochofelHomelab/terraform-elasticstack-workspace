locals {
  id = var.workspace_id

  # Data views: the workspace's own, one per type, then one per type for
  # each workspace it reads from. Keys and ids derive only from the ids, so
  # a dashboard exported from the space references the same data view in
  # every workspace (`<id>-<type>`), and ids are unique across spaces.
  own_data_views = {
    for t in var.data_types : t => {
      id    = "${local.id}-${t}"
      name  = title(t)
      title = "${t}-*-${local.id}"
    }
  }
  read_from_data_views = {
    for pair in setproduct(var.data_types, sort(var.read_from)) : "${pair[0]}/${pair[1]}" => {
      id    = "${local.id}-${pair[0]}-from-${pair[1]}"
      name  = "${title(pair[0])} (${pair[1]})"
      title = "${pair[0]}-*-${pair[1]}"
    }
  }
  data_views = merge(local.own_data_views, local.read_from_data_views)
}

resource "elasticstack_kibana_space" "this" {
  space_id          = local.id
  name              = var.display_name
  description       = var.description
  color             = var.color
  initials          = var.initials
  solution          = var.solution
  disabled_features = var.disabled_features

  lifecycle {
    precondition {
      condition     = !contains(var.read_from, local.id)
      error_message = "read_from must not contain the workspace itself."
    }
  }
}

resource "elasticstack_kibana_data_view" "this" {
  for_each = local.data_views

  space_id = elasticstack_kibana_space.this.space_id
  override = false

  data_view = {
    id              = each.value.id
    name            = each.value.name
    title           = each.value.title
    time_field_name = "@timestamp"
    # The workspace exists before its first document does.
    allow_no_index = true
  }
}

resource "elasticstack_kibana_default_data_view" "this" {
  space_id = elasticstack_kibana_space.this.space_id
  # try(): an unknown type fails on the precondition, with its message.
  data_view_id = try(elasticstack_kibana_data_view.this[var.default_data_type].data_view.id, null)
  force        = true

  lifecycle {
    precondition {
      condition     = contains(var.data_types, var.default_data_type)
      error_message = "default_data_type must be one of data_types."
    }
  }
}

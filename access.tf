# Workspace IAM: two roles and their group bindings, derived only from the
# workspace's inputs. Nobody has access by default; platform admins and
# service accounts are not the module's.

locals {
  # The same patterns as the data views: the workspace's own namespace and
  # the namespaces it reads from. Never a wildcard namespace.
  index_patterns = concat(
    [for t in var.data_types : "${t}-*-${local.id}"],
    [for pair in setproduct(var.data_types, sort(var.read_from)) : "${pair[0]}-*-${pair[1]}"],
  )

  # Both read the data and only the data: nobody writes through Kibana.
  # They differ in what they can do in the space.
  roles = {
    viewer = {
      kibana_base = "read"
      groups      = var.access.viewer_groups
      description = "Read-only access to the ${var.display_name} workspace: its space, dashboards, alerts and data."
    }
    editor = {
      kibana_base = "all"
      groups      = var.access.editor_groups
      description = "Edits the ${var.display_name} workspace's space (dashboards, rules, connectors) and reads its data."
    }
  }
}

resource "elasticstack_kibana_security_role" "this" {
  for_each = local.roles

  name        = "workspace-${local.id}-${each.key}"
  description = each.value.description

  elasticsearch {
    indices {
      names      = local.index_patterns
      privileges = ["read", "view_index_metadata"]
    }
  }

  kibana {
    base   = [each.value.kibana_base]
    spaces = [elasticstack_kibana_space.this.space_id]
  }
}

resource "elasticstack_elasticsearch_security_role_mapping" "this" {
  for_each = { for k, r in local.roles : k => r if length(r.groups) > 0 }

  name    = "workspace-${local.id}-${each.key}"
  enabled = true
  roles   = [elasticstack_kibana_security_role.this[each.key].name]

  # A `field` rule with a list matches any of its values.
  rules = (
    var.access.realm == null
    ? jsonencode({ field = { groups = sort(each.value.groups) } })
    : jsonencode({
      all = [
        { field = { "realm.name" = var.access.realm } },
        { field = { groups = sort(each.value.groups) } },
      ]
    })
  )
}

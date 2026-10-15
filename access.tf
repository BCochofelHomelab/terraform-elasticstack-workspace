# Workspace IAM, derived only from this module's inputs: what the roles can
# read (this workspace's data, its alerts, read_from grants) and where they
# can work (this space only). Bindings map identity-provider groups to the
# roles; group membership stays in the identity provider.

locals {
  read_patterns = concat(
    values(local.index_patterns),
    [local.alerts_index],
    flatten([for w in sort(tolist(var.read_from)) : [for t in sort(tolist(var.data_types)) : "${t}-*-${w}"]]),
  )

  roles = {
    viewer = "read"
    editor = "all"
  }

  realm_rule = var.access.realm == null ? [] : [{ field = { "realm.name" = var.access.realm } }]

  groups_by_role = {
    for role in keys(local.roles) : role => sort([for group, r in var.access.bindings : group if r == role])
  }
}

resource "elasticstack_kibana_security_role" "this" {
  for_each = local.roles

  name        = "workspace-${var.workspace}-${each.key}"
  description = "${title(each.key)} of workspace ${var.workspace} (owner: ${var.owner}). Managed by OpenTofu."

  elasticsearch {
    indices {
      names      = local.read_patterns
      privileges = ["read", "view_index_metadata"]
    }
  }

  kibana {
    base   = [each.value]
    spaces = [elasticstack_kibana_space.this.space_id]
  }
}

resource "elasticstack_elasticsearch_security_role_mapping" "this" {
  for_each = { for role, groups in local.groups_by_role : role => groups if length(groups) > 0 }

  name    = "workspace-${var.workspace}-${each.key}"
  enabled = true
  roles   = [elasticstack_kibana_security_role.this[each.key].name]
  rules = jsonencode({
    all = concat(local.realm_rule, [
      { any = [for g in each.value : { field = { groups = g } }] }
    ])
  })
}

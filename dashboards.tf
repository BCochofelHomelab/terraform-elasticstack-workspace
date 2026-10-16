# Saved objects: the baseline every workspace gets, rendered from
# templates/saved-objects with the workspace id, then the workspace's own
# exports. Both import into the space with overwrite, so the module's
# version wins over edits made in Kibana (docs/BASELINE-CONTENT.md).

locals {
  baseline_dir = "${path.module}/templates/saved-objects"
  baseline_templates = (
    var.baseline_content && contains(var.data_types, "logs")
    ? { for f in fileset(local.baseline_dir, "*.ndjson.tftpl") : trimsuffix(f, ".ndjson.tftpl") => f }
    : {}
  )

  # One object per line. Drops blank lines, the export summary (no `type`)
  # and data views: importing one would overwrite the module's.
  saved_objects = {
    for k, content in var.saved_objects : k => join("\n", [
      for line in split("\n", content) : line
      if can(jsondecode(line).type) && try(jsondecode(line).type != "index-pattern", false)
    ])
  }
}

resource "elasticstack_kibana_import_saved_objects" "baseline" {
  for_each = local.baseline_templates

  space_id      = elasticstack_kibana_space.this.space_id
  overwrite     = true
  file_contents = templatefile("${local.baseline_dir}/${each.value}", { workspace_id = local.id })

  # The objects reference the data views by id.
  depends_on = [elasticstack_kibana_data_view.this]
}

resource "elasticstack_kibana_import_saved_objects" "workspace" {
  for_each = local.saved_objects

  space_id      = elasticstack_kibana_space.this.space_id
  overwrite     = true
  file_contents = each.value

  lifecycle {
    precondition {
      condition     = length(trimspace(each.value)) > 0
      error_message = "saved_objects[\"${each.key}\"] has no saved objects (only data views, or empty)."
    }
  }

  # Workspace content may reference the data views and the baseline.
  depends_on = [
    elasticstack_kibana_data_view.this,
    elasticstack_kibana_import_saved_objects.baseline,
  ]
}

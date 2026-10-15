# Baseline saved objects ship with the module as templates, rendered per
# workspace; the workspace's own come in as plain NDJSON. One resource per
# file, so adding or changing one never re-imports the others.
#
# Removing a file stops managing its objects but doesn't delete them from
# Kibana: clean up by hand (docs/BASELINE-CONTENT.md).

locals {
  template_dir = "${path.module}/templates/saved-objects"

  baseline = {
    for f in fileset(local.template_dir, "*.ndjson.tftpl") :
    trimsuffix(f, ".ndjson.tftpl") => f
    if !contains(var.exclude_baseline_saved_objects, trimsuffix(f, ".ndjson.tftpl"))
  }

  # Every placeholder a baseline template may use. Referencing the data view
  # makes each import wait for it (implicit dependency).
  template_vars = {
    workspace          = var.workspace
    workspace_name     = local.name
    logs_data_view_id  = elasticstack_kibana_data_view.this["logs"].data_view.id
    logs_index_pattern = local.index_patterns["logs"]
  }
}

resource "elasticstack_kibana_import_saved_objects" "baseline" {
  for_each = local.baseline

  space_id      = elasticstack_kibana_space.this.space_id
  overwrite     = true
  file_contents = templatefile("${local.template_dir}/${each.value}", local.template_vars)
}

resource "elasticstack_kibana_import_saved_objects" "extra" {
  for_each = var.extra_saved_objects

  space_id      = elasticstack_kibana_space.this.space_id
  overwrite     = true
  file_contents = each.value

  # Extras reference the data views by their deterministic ids
  # (<id>-logs, ...), not by a Terraform reference: explicit ordering.
  depends_on = [elasticstack_kibana_data_view.this]
}

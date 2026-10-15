# Baseline content: adding or changing a dashboard

Saved objects reference data views by id, so an export from Kibana can't be
committed as is. The baseline is a set of templates rendered per workspace.

## Workflow

1. In a sandbox workspace (e.g. `sandbox`), build or change
   the dashboard against the `sandbox-logs` data view.
2. Export it: *Stack Management → Saved objects → Export* (include related
   objects).
3. Templatize it:

   ```bash
   scripts/templatize-saved-objects.py export.ndjson \
     --data-view-id sandbox-logs=logs_data_view_id \
     --workspace sandbox \
     > templates/saved-objects/<name>.ndjson.tftpl
   ```

4. Run `mise run lint` (the `saved_object_templates` hook renders and parses
   it), commit with `feat:` (new baseline content is a minor release), and
   let the integration tests import it.

Placeholders a template may use are the keys of `template_vars` in
`dashboards.tf`: `workspace`, `workspace_name`, `logs_data_view_id`,
`logs_index_pattern`. Add new ones there first.

## Rules of thumb

- Keep the baseline small: what **every** workspace needs. Its own
  dashboards belong in the workspace's folder (`extra_saved_objects`).
- Prefer simple object types (searches, Lens panels) over legacy
  visualizations: they survive Kibana upgrades better.
- Removing a template stops managing the object but doesn't delete it from
  existing spaces; clean up by hand.
- Editors can change baseline objects in the UI, but the next apply
  overwrites them. Copy a baseline dashboard to make your own version.

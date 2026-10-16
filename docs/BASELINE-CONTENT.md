# Baseline content

What every workspace gets in Kibana without asking, how a workspace adds
its own, and how the baseline changes.

## Saved objects

From [`templates/saved-objects/`](../templates/saved-objects), rendered
with the workspace id and imported into the space (`baseline_content`,
on by default; needs `logs` in `data_types`):

| Object | Id | What |
| --- | --- | --- |
| Dashboard **Overview** | `<id>-baseline-overview` | A **Service** selector (`service.name`) above the Errors and Logs searches, last 24 hours. |
| Discover session **Errors** | `<id>-baseline-errors` | Log lines matching `log.level: (error or ERROR)`. |
| Discover session **Logs** | `<id>-baseline-logs` | Every log line: `service.name`, `log.level`, `message`. |

Their ids include the workspace id: Kibana needs saved object ids unique
across spaces.

## Rules

Both on by default (`baseline_rules`), both tagged `baseline` and
`workspace:<id>`, both sending to `alert_actions`:

| Rule | Type | Fires when |
| --- | --- | --- |
| **No data** (`<id>-baseline_no_data`) | `.es-query`, every 5 minutes | No document arrived in any of the workspace's own data streams (`<type>-*-<id>`) in the last `no_data_minutes` (15). A new workspace fires until its first data arrives. |
| **Error rate** (`<id>-baseline_error_rate`) | `observability.rules.custom_threshold`, every minute | For one `service.name`, more than `error_rate_percent` (5) of its log lines in 5 minutes match `error_filter` (`log.level: (error or ERROR)`). Needs `logs`. |

Actions use the rule type's default action group (`query matched`,
`custom_threshold.fired`), and notify on action group change.

## Alert destinations

`alert_actions` is the workspace's default alert destination; every rule
that notifies sends to every entry. An entry names a connector:

- **`connector_id`**: a connector preconfigured in `kibana.yml`
  (`xpack.actions.preconfigured`), available in every space. Anything with
  a secret (SMTP password, webhook token) is configured this way, so no
  secret passes through a workspace's state.
- **`connector`**: a key of `connectors`, which the module creates in the
  space. Only connectors without secrets.

**The license matters:** on the basic license, Kibana offers only
`.server-log` and `.index` connectors; email, webhook and the rest need a
paid license (or a trial).

`params` is the connector type's JSON and applies to every rule. Write
messages with `{{rule.name}}`, and both `{{context.reason}}` (threshold
rules) and `{{context.message}}` (ES query rules): a variable a rule type
doesn't have renders empty.

## A workspace's own content

- **Dashboards and searches** (`saved_objects`): Kibana exports from the
  workspace's own space, passed as file contents. Data views in an export
  are dropped (the module owns them) along with the export's summary line,
  so "include related objects" is harmless. Because data view ids are
  `<id>-<type>` in every workspace, an export's references resolve.
- **Rules** (`rules`): by key, with the rule type's JSON params. Keys can't
  start with `baseline`. The module knows the default action group of the
  common rule types (ES query, index threshold, custom threshold, APM,
  logs and metrics thresholds); another type sets `action_group`.

Removing an entry from `saved_objects` stops managing those objects but
doesn't delete them from Kibana. Removing a rule deletes it.

**Edits made in Kibana are overwritten**: every import overwrites, and
rules are reconciled on each apply. To change content, export it, commit
the export, apply.

## Changing the baseline

1. Build or change the objects in a workspace's space (a throwaway one
   works) against the data views `<id>-logs`, `<id>-metrics`,
   `<id>-traces`.
2. Export them from Stack Management → Saved objects.
3. Templatize the export:

   ```bash
   scripts/templatize-saved-objects.py export.ndjson --workspace <id> \
     -o templates/saved-objects/<name>.ndjson.tftpl
   ```

   It drops data views and Kibana's bookkeeping fields, replaces the
   workspace id in ids, references and nested JSON with
   `${workspace_id}`, and escapes the rest for `templatefile()`.
4. Read the diff: anything specific to the source workspace that the
   script didn't catch (a display name in a title, say) is fixed by hand.
5. `mise run test` and `mise run test:integration`, then a pull request.

A new template is a new object in every workspace: `feat:`. Changing an
object's id, or removing one, is breaking: `feat!:`
([`RELEASING.md`](RELEASING.md)).

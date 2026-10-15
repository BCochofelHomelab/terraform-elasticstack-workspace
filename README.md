# terraform-elasticstack-workspace

OpenTofu module that turns one **workspace** id into a ready-to-use
observability space on Elastic: a Kibana space, data views, access roles
and bindings, baseline dashboards and baseline alerts, plus the
workspace's own dashboards and rules. It only uses the
`elastic/elasticstack` provider, so it works the same on a self-managed
cluster and on Elastic Cloud.

## Quickstart

```bash
mise trust && mise install   # pinned toolchain, git hooks, TFLint plugins
mise run check               # lint, secrets scan, validate, unit tests
mise run test:integration    # throwaway Elasticsearch + Kibana in Docker
```

## Usage

```hcl
module "workspace" {
  source = "git::https://github.com/BCochofelHomelab/terraform-elasticstack-workspace.git?ref=v1.0.0"

  workspace = "payments"          # permanent: the namespace, space id, role names
  owner     = "payments-platform" # one accountable owner

  access = {
    realm    = "oidc"
    bindings = { "grp-payments-engineers" = "editor" }
  }

  extra_saved_objects = {
    for f in fileset("${path.module}/dashboards", "*.ndjson") :
    trimsuffix(f, ".ndjson") => file("${path.module}/dashboards/${f}")
  }
}
```

The caller configures the `elasticstack` provider. Data for the workspace
must be written with `namespace = <workspace>`: that convention is the
module's only contract with the rest of the platform.

## What it creates

| Resource | Convention |
| --- | --- |
| Kibana space | id = workspace id; name, colour, solution view, hidden features; owner in the description |
| Data views for logs, metrics, traces | `<type>-*-<workspace>`, ids `<workspace>-<type>`, logs is the default |
| Roles `workspace-<id>-viewer` / `-editor` | read the workspace's data, its alerts and `read_from` grants; this space only |
| Role mappings | one per role with at least one binding, optionally limited to one realm |
| Baseline saved objects | `templates/saved-objects/`, rendered per workspace |
| Workspace saved objects | NDJSON passed in, one resource per file |
| Index connector + baseline rules | error rate and no data, rule ids `<workspace>-<key>` |
| Workspace rules | the same rule type, on the workspace's own data, same destinations |

Not here: the cluster, Fleet (agent and integration policies belong to
host groups), integration packages, ILM, templates, ingest pipelines,
Logstash, platform IAM.

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): what a workspace is, the
  namespace contract, access model, why the module is shaped this way
- [docs/BASELINE-CONTENT.md](docs/BASELINE-CONTENT.md): adding or changing
  a baseline dashboard
- [docs/RELEASING.md](docs/RELEASING.md): tests, releases, consuming by tag
- [CONTRIBUTING.md](CONTRIBUTING.md): how a change flows, checks, toolchain

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.0 |
| <a name="requirement_elasticstack"></a> [elasticstack](#requirement\_elasticstack) | >= 0.16.0, < 1.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_elasticstack"></a> [elasticstack](#provider\_elasticstack) | >= 0.16.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [elasticstack_elasticsearch_security_role_mapping.this](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/elasticsearch_security_role_mapping) | resource |
| [elasticstack_kibana_action_connector.index](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/kibana_action_connector) | resource |
| [elasticstack_kibana_alerting_rule.this](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/kibana_alerting_rule) | resource |
| [elasticstack_kibana_data_view.this](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/kibana_data_view) | resource |
| [elasticstack_kibana_default_data_view.this](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/kibana_default_data_view) | resource |
| [elasticstack_kibana_import_saved_objects.baseline](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/kibana_import_saved_objects) | resource |
| [elasticstack_kibana_import_saved_objects.extra](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/kibana_import_saved_objects) | resource |
| [elasticstack_kibana_security_role.this](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/kibana_security_role) | resource |
| [elasticstack_kibana_space.this](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs/resources/kibana_space) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_owner"></a> [owner](#input\_owner) | The one accountable owner (a team or a person's role, not a group of teams). Shown in the space description and tagged on every rule. | `string` | n/a | yes |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | Workspace id: permanent, and baked into data stream names as the<br/>namespace (`<type>-<dataset>-<workspace>`), the Kibana space id, data view<br/>ids and role names. Name it after what is observed, not after a team.<br/>Lowercase letters, digits and underscores (namespaces can't contain<br/>hyphens), and never `default`. | `string` | n/a | yes |
| <a name="input_access"></a> [access](#input\_access) | Who gets into the workspace. Roles workspace-<id>-viewer and<br/>workspace-<id>-editor always exist; `bindings` maps an identity-provider<br/>group to one of them (the group's membership is managed in the identity<br/>provider, not here). `realm` limits the mappings to one realm, e.g. the<br/>OIDC realm. No bindings means nobody has access by default. | <pre>object({<br/>    realm    = optional(string)<br/>    bindings = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_alerting"></a> [alerting](#input\_alerting) | Baseline alerting. `index_connector` writes every alert to<br/>alerts-workspace-<id> (works on the basic license). `destinations` are<br/>existing connectors (e.g. a ServiceNow or email connector, preconfigured<br/>or managed in the platform repo) that every rule notifies, each with its<br/>action params. The first destination is the workspace's default alert<br/>destination. | <pre>object({<br/>    enabled         = optional(bool, true)<br/>    index_connector = optional(bool, true)<br/>    destinations = optional(list(object({<br/>      connector_id = string<br/>      params       = any<br/>    })), [])<br/>    interval               = optional(string, "5m")<br/>    error_threshold        = optional(number, 50)<br/>    error_window_minutes   = optional(number, 5)<br/>    no_data_window_minutes = optional(number, 15)<br/>  })</pre> | `{}` | no |
| <a name="input_color"></a> [color](#input\_color) | Space avatar colour, as #RRGGBB. Null lets Kibana derive one from the name. | `string` | `null` | no |
| <a name="input_data_types"></a> [data\_types](#input\_data\_types) | Data stream types the workspace receives: one data view each. Must include "logs": the baseline content and rules use it. | `set(string)` | <pre>[<br/>  "logs",<br/>  "metrics",<br/>  "traces"<br/>]</pre> | no |
| <a name="input_description"></a> [description](#input\_description) | What the workspace observes, in one sentence. | `string` | `null` | no |
| <a name="input_disabled_features"></a> [disabled\_features](#input\_disabled\_features) | Kibana feature ids hidden in the space (the Features API lists them). | `set(string)` | `[]` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Space display name. Can change at any time, unlike the id. Defaults to the id in title case. | `string` | `null` | no |
| <a name="input_exclude_baseline_saved_objects"></a> [exclude\_baseline\_saved\_objects](#input\_exclude\_baseline\_saved\_objects) | Baseline saved-object templates (file names in templates/saved-objects, without extension) not to install in this workspace. | `set(string)` | `[]` | no |
| <a name="input_extra_saved_objects"></a> [extra\_saved\_objects](#input\_extra\_saved\_objects) | The workspace's own saved objects (dashboards, searches, visualizations)<br/>as NDJSON contents, keyed by a stable name. Typically every *.ndjson<br/>file in the workspace's dashboards/ folder, keyed by file name. | `map(string)` | `{}` | no |
| <a name="input_read_from"></a> [read\_from](#input\_read\_from) | Other workspaces whose data this workspace's roles may read, e.g. a shared<br/>platform workspace. Grants read on their data streams only, not their<br/>spaces. The owner of the data being read approves the grant (in the<br/>platform repo, through CODEOWNERS). | `set(string)` | `[]` | no |
| <a name="input_rules"></a> [rules](#input\_rules) | The workspace's own Elasticsearch query rules, keyed by a stable name.<br/>Each queries only this workspace's data of `data_type` and notifies the<br/>same destinations as the baseline rules. `query` is a raw Elasticsearch<br/>query object, e.g. { query = { match = { "service.name" = "checkout" } } }. | <pre>map(object({<br/>    name           = optional(string)<br/>    data_type      = optional(string, "logs")<br/>    query          = any<br/>    comparator     = optional(string, ">")<br/>    threshold      = number<br/>    window_minutes = optional(number, 5)<br/>  }))</pre> | `{}` | no |
| <a name="input_solution"></a> [solution](#input\_solution) | Kibana solution view for the space: oblt, es, security or classic. Null keeps Kibana's default. Needs a Kibana that supports solution views. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alerts_index"></a> [alerts\_index](#output\_alerts\_index) | Index the workspace's index connector writes alert documents to. |
| <a name="output_connector_ids"></a> [connector\_ids](#output\_connector\_ids) | Connector ids every rule notifies, index connector first. |
| <a name="output_data_view_ids"></a> [data\_view\_ids](#output\_data\_view\_ids) | Data view id per data type. Workspace saved objects reference these. |
| <a name="output_index_patterns"></a> [index\_patterns](#output\_index\_patterns) | Index pattern per data type, e.g. { logs = "logs-*-payments" }. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | The namespace this workspace's data must be written with: set it on Fleet integration policies, APM and Logstash outputs. |
| <a name="output_role_names"></a> [role\_names](#output\_role\_names) | Role name per access level (viewer, editor). |
| <a name="output_rule_ids"></a> [rule\_ids](#output\_rule\_ids) | Rule ids keyed by rule key: error\_rate, no\_data and every key of var.rules. |
| <a name="output_space_id"></a> [space\_id](#output\_space\_id) | Kibana space id (equals the workspace id). |
<!-- END_TF_DOCS -->

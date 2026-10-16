# Architecture

What the module is, what it isn't, and why.

## A workspace

A **workspace** is observability data and resources that share one owner
and one audience: the unit of access, alert ownership and automation. A
good workspace passes four tests:

1. It has one accountable owner.
2. It outlives a reorganisation: it's named after what is observed, not the
   team.
3. It has one audience: anyone who may see part of it may see all of it.
4. It has one default alert destination.

Its **id** is permanent and is used three ways at once: the Kibana space
id, the data stream namespace (`<type>-<dataset>-<id>`) and part of every
derived name. A namespace can't contain `-`, so ids allow only `a-z`, `0-9`
and `_`, which also means `logs-*-<id>` can only ever match that
workspace's data. `default` is excluded: it's Kibana's default space and
the namespace of everything nobody routed. The display name can change at
any time; the id never does.

## What the module creates

```text
workspace_id ──► space <id>
             ├─► data views <id>-<type>             title <type>-*-<id>
             │   data views <id>-<type>-from-<w>    title <type>-*-<w>   (read_from)
             ├─► default data view                  <id>-<default_data_type>
             ├─► role workspace-<id>-viewer         space: read  data: read
             ├─► role workspace-<id>-editor         space: all   data: read
             ├─► role mappings (groups [+ realm])   only for kinds with groups
             ├─► baseline saved objects             <id>-baseline-*   (templates/saved-objects)
             ├─► workspace saved objects            its own exports, data views dropped
             ├─► connectors (no secrets)            in the space
             └─► rules <id>-baseline_no_data, <id>-baseline_error_rate, <id>-<key>
                       all → alert_actions
```

- **Deterministic data view ids.** A dashboard exported from one
  workspace's space references `<id>-logs`; the same names exist in every
  workspace, so baseline content renders per workspace by substituting the
  id. Including the id keeps them unique across spaces, which Kibana needs.
- **Both roles read the data and nothing else.** Nobody writes data through
  Kibana; data is written at ingest with the namespace set. They differ only
  in what they can do in the space.
- **No access by default.** A kind without groups gets no role mapping.
  Native users are given the role names directly.
- **`read_from`** is the only way a workspace sees another's data, entry by
  entry, and the owner of the data being read approves the line (in the
  platform repo, through CODEOWNERS). It adds read privileges and a data
  view per type; it never widens a pattern.

- **Baseline content is a template of an export**, rendered per workspace
  ([`BASELINE-CONTENT.md`](BASELINE-CONTENT.md)). It's written in Kibana,
  not by hand, so it's always in a format Kibana produced.
- **No secret passes through a workspace.** A connector that needs one is
  preconfigured in `kibana.yml` and referenced by id; the module only
  creates connectors without secrets.

## What it deliberately leaves out

| Not here | Why | Where it lives |
| --- | --- | --- |
| Fleet agent and integration policies, enrollment tokens | A policy belongs to a host group, not a workspace: a shared host carries integrations for several workspaces but enrolls in one policy, and the enrollment token must reach Ansible, which a workspace stack shouldn't hold. | `homelab-proxmox-platform`, `agent-policies/<group>/` |
| Integration packages, ILM, index templates, ingest pipelines, SSO realm, platform roles | Platform-wide: a change affects everyone, so it belongs to the narrowest scope that contains everyone, the shared one. Retention is platform-wide. | `homelab-proxmox-platform`, `shared/` |
| A separate IAM module | Roles and mappings derive only from the workspace's inputs. A separate module would compute the same names twice, need coordinated releases, and isolate nothing (same state, same credential). | Here, `access.tf` |

Isolation between workspaces comes from the consumer's stack boundaries
(one state, one plan, one API key per workspace), not from this module.

## Only the `elastic/elasticstack` provider

`>= 0.16.5, < 1.0.0`. The upper bound is deliberate while the provider is
pre-1.0: a 0.x minor may break, and a consumer must not pick one up
before this module is tested with it. Anything environment-specific (the
SSO realm, a connector by id) is an input, never a branch in the code.

## The contract with the platform

The namespace convention is the only coupling: data for workspace `<id>`
is written with `namespace = <id>` (Fleet integration policies, the APM
path, Logstash pipelines). The platform checks it: ids are validated in CI,
every integration policy's namespace must name an existing workspace, and a
rule in the `platform` workspace alerts on data in a namespace with no
workspace.

## Testing

- **Unit** (`tests/*.tftest.hcl`): `tofu test` with `mock_provider`. Plans
  only; checks names, patterns, mappings and every input validation. Runs as
  a pre-commit hook, so on every commit and in CI.
- **Integration** (`tests/integration/`): a throwaway single-node
  Elasticsearch + Kibana 9.5.4 in Docker on GitHub's runners (security on,
  basic license, random passwords per run). `tofu test` applies, asserts,
  updates in place and destroys; then the example is applied and its plan
  must be empty, which catches drift between what the module sends and what
  the APIs return. No secrets, no self-hosted runner.

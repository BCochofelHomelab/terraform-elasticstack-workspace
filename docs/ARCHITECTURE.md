# Architecture

## What a workspace is

A workspace is a container for observability data and resources that share
**one owner and one audience**. It is the unit of access, alert ownership
and automation.

A good workspace passes four tests:

1. **One accountable owner.**
2. **It outlives a reorganisation:** it is named after what is observed,
   not after the team that observes it.
3. **One audience:** anyone who may see part of it may see all of it. A
   Kibana space is the access boundary; there is no finer one inside it.
4. **One default alert destination.**

Region and environment are fields of the data, not part of the id.

The id is permanent, because it is baked into the data: it is the
**namespace** of every data stream the workspace receives
(`<type>-<dataset>-<workspace>`). The display name can change at any time.
Ids allow only `[a-z0-9_]` (namespaces can't contain hyphens) and can't be
`default`.

## The namespace contract

The module never writes data and never configures Fleet. It assumes the
platform writes the workspace's data with `namespace = <workspace>`, in one
of three places: Fleet integration policies, the APM path, or Logstash
pipelines. Everything the module creates (data views, roles, rules) is
built from `<type>-*-<workspace>`. The `namespace` output says which value
to use.

## Access model

| Layer | Lives in | Changed by |
| --- | --- | --- |
| Role definitions (viewer, editor) | this module, `access.tf` | a module release |
| Bindings: group → role | the caller (`access.bindings`) | a pull request in the platform repo |
| Membership: who is in each group | the identity provider | the group's owner, no pull request |

Nobody has access by default. `read_from` grants a workspace's roles read
access to another workspace's **data** (never its space). The owner of the
data being read approves the grant.

Platform administrators, service accounts and per-stack API keys are not
here: they belong to the platform.

## Why the module is shaped like this

- **Only the `elastic/elasticstack` provider.** It stays backend-agnostic
  and testable on its own. Anything environment-specific (OIDC realm,
  ServiceNow or email connectors) is an input, never a branch in the code.
- **It encodes a product, not a resource wrapper.** One id in, a whole
  workspace out, built the same way every time.
- **Workspace IAM lives here** because it is derived only from the module's
  inputs. A separate IAM module would compute the same names twice and need
  coordinated releases, with no isolation gained.
- **No Fleet.** An agent policy belongs to a host group, not a workspace: a
  shared host carries integrations for several workspaces but enrolls in
  one policy, and its enrollment token must reach Ansible.
- **One file per concern:** `main.tf` (space, data views), `access.tf`,
  `dashboards.tf`, `alerting.tf`. No submodules: none of the parts is useful
  on its own.

## Self-managed vs Elastic Cloud

| Concern | Self-managed (homelab) | Elastic Cloud (work) |
| --- | --- | --- |
| Identity for bindings | native or OIDC realm | Entra ID groups via OIDC |
| Default alert destination | index connector, or email/webhook by id | ServiceNow connector by id |
| Everything else | identical | identical |

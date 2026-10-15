# CLAUDE.md

Project context for Claude Code sessions — **not for humans**: never link or
reference this file from `README.md`, `CONTRIBUTING.md`, or anything under
`docs/`. A human contributor's path is `README.md` -> `docs/*.md` ->
`CONTRIBUTING.md`. Repo conventions (lanes, devcontainer, machine user,
credentials, mise, pre-commit, releases) follow homelab-proxmox-core; its
CLAUDE.md is the reference for anything this file doesn't say. The
homelab-wide SRE AI-autonomy roadmap is core's `docs/SRE-AI.md`.

## What this is

A reusable OpenTofu module: one **workspace** id in, a ready-to-use
observability space on Elastic out (space, data views, roles and bindings,
baseline dashboards and rules, plus the workspace's own content). Consumed
by exact tag from homelab-proxmox-platform (one Terramate stack per
workspace) and, as a reference, by the work platform on Elastic Cloud. The
design record is `docs/ARCHITECTURE.md`.

## Decisions that are deliberate (do not "fix" these)

- **`elastic/elasticstack` only.** No provider blocks, no other providers:
  the module must run unchanged on self-managed and Elastic Cloud.
  Environment differences (realm, connectors) are inputs, never branches.
- **Namespace = workspace id** is the only contract with the platform.
  Everything is built from `<type>-*-<workspace>`. Ids are
  `^[a-z0-9_]{1,64}$` and never `default`.
- **Anything derived from the id is permanent:** space id, data view ids
  (`<id>-<type>`), role names (`workspace-<id>-viewer|editor`), rule ids
  (`<id>-<key>`), the alerts index, the index connector's UUIDv5. Renaming
  any of them is a major release.
- **Workspace IAM lives here** (derived from inputs only). Platform IAM,
  service accounts, API keys and Elastic Cloud org membership never do.
- **No Fleet, ILM, templates, ingest pipelines or integration packages.**
  Agent policies belong to host groups in the platform repo.
- **Nobody has access by default.** No bindings, no role mappings.
- **One rule shape.** Baseline and workspace rules are normalised to the
  same object type (query already `jsonencode`d) before `merge()`: mixing
  shapes in a conditional `for_each` was a real bug (unit test
  `workspace_rules_join_the_baseline`).
- **Provider `>= 0.16.0, < 1.0.0`**: floor = the version validated and
  tested; upper bound on purpose while the provider is pre-1.0.
- **No lock file committed** (`.gitignore`): consumers pin providers.
- **Tags are `vX.Y.Z`**, unlike core's unprefixed tags (`.releaserc.js`).
- **Baseline saved objects are templates** (`*.ndjson.tftpl`) made with
  `scripts/templatize-saved-objects.py`, never hand-edited exports.
  Placeholders must exist in `dashboards.tf`'s `template_vars`; the
  `saved_object_templates` hook checks it.
- **No secrets, real hostnames, realms or emails** in this public repo.

## Provider reference

Read resource schemas before writing or changing a resource, never from
memory: the Terraform MCP server (`.mcp.json`, registry toolset) or
https://search.opentofu.org/provider/elastic/elasticstack/latest. Notable
schema facts this module relies on:

- `kibana_alerting_rule`: `rule_id` accepts any string from Kibana 8.17;
  rule-level `notify_when` is deprecated, use `actions.frequency`.
- `kibana_action_connector`: `connector_id` must be a UUID (hence uuidv5).
- `kibana_default_data_view`: per space; `skip_delete` because the space
  is destroyed anyway.
- `kibana_security_role`: `kibana.base` and `kibana.feature` are exclusive.

## Standing rules

- Every new input is typed, documented, `nullable = false` for
  collections, and has a unit test; every validation has an
  `expect_failures` test.
- Add a capability when a workspace needs it (next: SLOs, synthetics
  monitors; later: maintenance windows), not upfront.
- Never run anything against a real cluster. The integration tests start
  their own throwaway stack.

## Commands

```bash
mise run check             # lint, gitleaks, validate, unit tests (no credentials)
mise run test:integration  # needs Docker: not available in the devcontainer
mise run docs              # regenerate README's terraform-docs section
```

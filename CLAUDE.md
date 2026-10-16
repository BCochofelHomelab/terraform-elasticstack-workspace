# CLAUDE.md

Project context for Claude Code sessions — **not for humans**: never link or
reference this file from `README.md`, `CONTRIBUTING.md` or anything under
`docs/`. In those, say "the AI agent", not "Claude Code", except where the
text is about the product itself.

## What this is

`terraform-elasticstack-workspace`: a reusable OpenTofu module for the
homelab's Elastic Stack. One **workspace** id in; out comes everything that
workspace needs in Kibana and Elasticsearch: a space, data views
`<type>-*-<id>`, viewer/editor roles with their group bindings, baseline
dashboards and rules, plus the workspace's own content. It's consumed by
`homelab-proxmox-platform` (one Terramate stack per workspace), by exact tag.

Homelab only: one self-managed Elastic Stack (version `9.5.4`), no Elastic
Cloud, no Entra ID.

## Decisions that are deliberate (do not "fix" these)

- **Only the `elastic/elasticstack` provider**, `>= 0.16.5, < 1.0.0`: the
  upper bound is on purpose while the provider is pre-1.0. Anything
  environment-specific (the SSO realm, a connector by id) is an input,
  never a branch in the code.
- **Workspace ids match `^[a-z0-9_]{1,64}$` and are never `default`.** The
  id is the data stream namespace, which can't contain `-`, so
  `logs-*-<id>` can only ever match that workspace's data.
- **Workspace IAM lives in the module** (roles, mappings, `read_from`
  grants): they derive only from the workspace's inputs. A separate IAM
  module would compute the same names twice and isolate nothing.
- **No Fleet in the module.** An agent policy belongs to a host group, not a
  workspace (`homelab-proxmox-platform`'s `agent-policies/`). Nor are
  integration packages, ILM, index templates or ingest pipelines: those are
  platform-wide.
- **No lock file is committed**: each consumer locks its own providers.
- **Tests need no secrets and no self-hosted runner**: unit tests use
  `mock_provider`; integration tests start a throwaway Elasticsearch and
  Kibana in Docker on GitHub's runners.

## The guardrails (the same as homelab-proxmox-core's)

- **The AI agent works only in its devcontainer** (`.devcontainer/`), in its
  own clone (`~/Projects/ai-agent/terraform-elasticstack-workspace`), as the
  machine user `bcochofel-ai-agent`: only the `ai-agent` age key,
  `homelab-ro.yaml` and `ai-agent-git.yaml` are mounted. `mise run
  check:boundary` proves it.
- **The agent never writes `.github/workflows/`**: its token can't push
  them. Workflow changes go in the pull request's description, for the
  human to commit.
- **Every change is a pull request**; `sre-lead` (the human) owns every file
  (`.github/CODEOWNERS`) and is the only one who merges.
- `.claude/settings.json` denies reading keys and secrets, decrypting,
  destroying, merging, approving, tagging, releasing and `gh api` writes;
  `mise exec` is denied because it could wrap any of them.
- Every tool is pinned in `mise.toml` (locked in `mise.lock`), with core's
  versions. mise itself is `MISE_VERSION` in `.devcontainer/post-create.sh`
  and `version:` in every workflow's `jdx/mise-action` step; pre-commit
  `mise_version` fails when they differ.
- Never name the repository this design replaced, in any file.

## Commands

```bash
mise trust && mise install   # the pinned toolchain, git hooks, TFLint plugins
mise run lint                # every pre-commit hook on every file
mise run check               # lint + gitleaks on the full history (what CI runs)
mise run check:boundary      # the agent's boundary holds
mise run test                # unit tests (mock_provider)
mise run test:integration    # needs Docker: not in the devcontainer
```

The devcontainer has no Docker socket, by design: to run the integration
tests locally, start Elasticsearch and Kibana 9.5.4 from Elastic's tarballs
in the scratchpad (same settings as `tests/integration/compose.yml`) and
run `tofu test -test-directory=tests/integration` with `ELASTICSEARCH_*` /
`KIBANA_*` exported in that command only.

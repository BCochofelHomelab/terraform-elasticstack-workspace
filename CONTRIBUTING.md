# Contributing

How a change gets into this module, whether you make it or the AI agent
does. It's the same flow as
[`homelab-proxmox-core`](https://github.com/BCochofelHomelab/homelab-proxmox-core/blob/main/CONTRIBUTING.md),
whose docs also explain the AI agent's setup and the reasons behind it.

## How a change flows

Every change goes through a pull request, and only you merge.

- **The AI agent** works in its devcontainer, in its own clone
  (`~/Projects/ai-agent/terraform-elasticstack-workspace`), as its machine
  user, `bcochofel-ai-agent`. It branches, makes the change, runs the
  checks, pushes and opens the pull request. It can't push
  `.github/workflows/` (those changes go in the pull request's description,
  for you to commit), merge, approve, tag or release.
- **You** work in your own clone, as you, with the same branch, commit and
  pull request flow. Yours is the only lane that changes workflows, reviews
  and merges.

Every pull request needs your approval as code owner (`sre-lead`), and every
review conversation resolved. **Merge right after you approve**: once
approved, GitHub would let any user with Write merge, the machine user
included. Squash or rebase merges only (linear history).

## Branches

Short-lived branches off `main`, deleted after merge, named
`<prefix>/<description>` ([Conventional Branch](https://conventionalbranch.org/)):
`feature/` (or `feat/`), `bugfix/` (or `fix/`), `hotfix/`, `release/`,
`chore/`. Lowercase letters, numbers and hyphens only.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/), checked by
commitlint ([`commitlint.config.js`](commitlint.config.js)):
`<type>(optional scope): <subject>`, with type `feat`, `fix`, `docs`,
`style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore` or `revert`.
`git commit` without `-m` opens the repo's template.

## Checks

`mise install` installs the git hooks, so `git commit` runs
[`.pre-commit-config.yaml`](.pre-commit-config.yaml): file hygiene,
markdownlint, OpenTofu (fmt, validate, terraform-docs, TFLint), ShellCheck,
gitleaks, actionlint and zizmor on workflows, and commitlint. CI runs the
same.

```bash
mise run lint               # every hook on every file
mise run check              # the above + gitleaks on the full history (what CI runs)
mise run test               # unit tests: tofu test with a mocked provider (also a hook)
mise run test:integration   # a throwaway Elasticsearch + Kibana 9.5.4 in Docker
```

CI's `integration` job runs `scripts/integration.sh` on GitHub's runners:
apply, assert, update, no drift, destroy, on a stack that only lives for
the job. How the tests are built: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md#testing).

Releases are automatic on merge, from the commit types:
[`docs/RELEASING.md`](docs/RELEASING.md). A change that renames anything
derived from the workspace id, or removes or retypes an input or output,
is breaking (`feat!:`).

Two repo-specific rules the hooks enforce:

- **A secret-named OpenTofu variable** (token, secret, password, hash,
  private key, API key) has no default and is `sensitive = true`. A name
  that only looks secret goes in the allowlist of
  [`scripts/check_secret_variables.py`](scripts/check_secret_variables.py),
  with the reason.
- **mise itself** is pinned once: `MISE_VERSION` in
  `.devcontainer/post-create.sh`, and `version:` in every workflow's
  `jdx/mise-action` step
  ([`scripts/check_mise_version.py`](scripts/check_mise_version.py)).

## Toolchain

Every command-line tool is pinned in [`mise.toml`](mise.toml), with each
download's checksum in `mise.lock`, at the same versions as
`homelab-proxmox-core`: your workstation, CI and the devcontainer run the
same versions. `mise tasks` lists the repo's commands.

| Tool | For |
| --- | --- |
| OpenTofu (`tofu`) | The module, its tests and examples. |
| TFLint, terraform-docs | Linting and docs for the module. |
| ShellCheck, markdownlint-cli2, actionlint, zizmor | Shell scripts, Markdown, and GitHub workflows (lint and security). |
| gitleaks | No secret committed: staged changes, and the full history in CI. |
| SOPS, age | Only the AI agent's credentials, in its devcontainer; this repo holds no secrets. |
| pre-commit, commitlint | Hooks and commit messages. |
| GitHub CLI (`gh`) | Pull requests and runs; the machine user's in the devcontainer. |
| Python, uv, Node.js | The runtimes for pre-commit and its hooks. |
| github-mcp-server, terraform-mcp-server | The AI agent's read-only MCP servers. |

**Bumping a version:** nothing updates on its own (no Dependabot, no
Renovate). `mise run outdated` lists newer versions; edit the pin, then
`mise lock`, `mise run lint`, and commit the pin with its lockfile. Keep
versions in step with `homelab-proxmox-core`.

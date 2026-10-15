# Contributing

How a change gets into the module, whether you make it or the AI agent
does. It follows homelab-proxmox-core's CONTRIBUTING.md: the same two
lanes, branch and commit rules and toolchain. This page only lists what's
different here.

## How a change flows

Every change goes through a pull request.

- **The AI agent's lane:** it works in its devcontainer, as its machine
  user, branches, runs `mise run check`, pushes and opens the pull request.
  It can't push `.github/workflows/` (those changes go in the pull
  request's description), merge, approve or tag. It has no Docker socket,
  so it can't run the integration tests; CI does.
- **Your lane:** review, approve and merge. The merge releases: there is no
  apply step, because a module is only applied by the repos that consume
  it.

## Branches

Short-lived branches off `main`, named `<type>/<short-description>` (for
example `feat/slo-baseline`), deleted after merge. Never commit to `main`:
the `no-commit-to-branch` hook refuses it.

## Commits and releases

Conventional Commits, checked by commitlint on every commit. The type
decides the release ([docs/RELEASING.md](docs/RELEASING.md)), so pick it
for what the change means to a consumer: a new input is `feat:`, a renamed
one is `feat!:`.

## Checks

| Check | Local | CI |
| --- | --- | --- |
| pre-commit (fmt, validate, docs, tflint, trivy, gitleaks, shellcheck, actionlint, zizmor, commitlint, template rendering) | on every commit | `check` job |
| gitleaks over the full history | `mise run lint:secrets` | `check` job |
| validate the module and examples | `mise run validate` | `check` job |
| unit tests (mocked provider) | `mise run test` | `check` job |
| integration tests (Docker) | `mise run test:integration` | `integration` job, per stack version |

`mise run check` runs everything except the integration tests.

## Toolchain

`mise trust && mise install` installs every pinned tool and the git
hooks. The versions match homelab-proxmox-core's `mise.toml`: bump them
there and here together, then `mise lock` and commit `mise.toml`,
`mise.lock` and `.mise/locks/`. CI installs in locked mode.

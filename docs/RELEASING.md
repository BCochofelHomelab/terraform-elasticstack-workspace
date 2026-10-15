# Testing, releasing and consuming

## Test layers

| Layer | Command | Where | Needs |
| --- | --- | --- | --- |
| Lint | `mise run lint` | CI `check` | nothing |
| Validate | `mise run validate` | CI `check` | registry access |
| Unit | `mise run test` | CI `check` | nothing: `mock_provider` |
| Integration | `mise run test:integration` | CI `integration`, per stack version | Docker |

Unit tests check the module's own logic: ids and validations, the shape of
roles and mappings, which rules exist and what they query. Integration tests
prove the real APIs accept what the module sends, on every stack version in
the matrix. Everything runs on GitHub-hosted runners with generated
throwaway credentials: no repository secrets and no self-hosted runner.

## Releases

On every push to `main` (a merged pull request), semantic-release reads
the Conventional Commits since the last tag and creates `vX.Y.Z` plus a
GitHub release with notes. Nothing is committed back to `main`.

| Commit | Release |
| --- | --- |
| `fix:` | patch |
| `feat:` (including new baseline content) | minor |
| `feat!:` or a `BREAKING CHANGE:` footer | major |

Breaking changes:

- renaming anything derived from the workspace id (space, data views,
  roles, rule ids, index patterns, alerts index);
- removing an input or an output, or changing a type;
- changing a resource address without a `moved` block.

Repository settings, the same as homelab-proxmox-core:

- `protected-default` ruleset on `main`, with CI's `check` and
  `integration` jobs as required status checks and a code-owner approval;
- `protected-tags` on `v*`: block update and delete, so a released tag
  never moves.

## Consuming from Git

Git module sources aren't recorded in `.terraform.lock.hcl`, so the tag is
the only pin. Always pin an exact, immutable tag:

```hcl
module "workspace" {
  source = "git::https://github.com/BCochofelHomelab/terraform-elasticstack-workspace.git?ref=v1.2.3"
}
```

Never a branch or a moving tag: an upgrade would happen silently at the
next `tofu init -upgrade`, with no diff in the consumer repo.

In the platform repo the ref is set **per workspace** (`workspace.yaml`),
so a new baseline can be rolled out to one workspace first, like a canary,
and to the rest once it looks right.

## Provider constraint

`>= 0.16.0, < 1.0.0`. The floor is the provider version the module is
validated and tested against. The upper bound is deliberate while the
provider is pre-1.0, even though a reusable module normally sets a minimum
only. When the provider ships 1.0.0: run the integration matrix against it,
then widen to `< 2.0.0`.

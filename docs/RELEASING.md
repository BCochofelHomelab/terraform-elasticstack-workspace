# Releasing

Releases are cut by [semantic-release](https://semantic-release.gitbook.io)
on every push to `main` (`.github/workflows/release.yml`,
[`.releaserc.js`](../.releaserc.js)), from the Conventional Commits merged
since the last tag. Nobody tags by hand. The setup is
`homelab-proxmox-core`'s.

## Versions

Tags are the bare version, without a `v`: `1.0.0`, `1.1.0`. A merge with
only `docs:`, `chore:`, `test:` or `ci:` commits releases nothing.

| Change | Commit | Release |
| --- | --- | --- |
| A new capability or input with a default | `feat:` | minor |
| A fix that keeps every name and input | `fix:` | patch |
| Anything a consumer must act on | `feat!:` / `fix!:`, or a `BREAKING CHANGE:` footer | major |

**Breaking**, so a major:

- renaming anything derived from the workspace id: the space, data view
  ids, role or role mapping names (Kibana and Elasticsearch replace them,
  and saved objects referencing them break);
- removing or renaming an input or output, or changing its type;
- a new required input, or a default that changes what existing workspaces
  get in a way they must act on;
- narrowing the provider constraint.

## Consuming a release

Git module sources aren't in the dependency lock file, so pin the exact
tag:

```hcl
source = "git::https://github.com/BCochofelHomelab/terraform-elasticstack-workspace.git?ref=1.0.0"
```

In `homelab-proxmox-platform` the ref is pinned per workspace
(`workspace.yaml`), so a new release is canaried on one workspace before
the others move to it.

## Release dependencies

`package.json` and `package-lock.json` hold semantic-release and its
plugins, only for the release workflow (`npm ci`). Node comes from
`mise.toml`. `conventional-changelog-conventionalcommits` stays at `^9`
until `@semantic-release/release-notes-generator` moves to
`conventional-changelog-writer@9` (the reason is in `.releaserc.js`).

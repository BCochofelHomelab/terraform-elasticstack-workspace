# terraform-elasticstack-workspace

An OpenTofu module that turns one **workspace** id into a ready-to-use
place in the homelab's Elastic Stack: a Kibana space, data views for the
workspace's data, viewer and editor roles bound to groups, and baseline
dashboards and alerts. A workspace then adds its own dashboards and rules
without touching anyone else's.

It's used by
[`homelab-proxmox-platform`](https://github.com/BCochofelHomelab/homelab-proxmox-platform),
one stack per workspace, and takes its conventions and guardrails from
[`homelab-proxmox-core`](https://github.com/BCochofelHomelab/homelab-proxmox-core).

## Vocabulary

| Term | Meaning |
| --- | --- |
| **Workspace** | Observability data and resources with **one owner and one audience**: the unit of access, alert ownership and automation. Its id is permanent; its display name can change. |
| **Namespace** | The last part of a data stream's name, `<type>-<dataset>-<namespace>`. The namespace **is** the workspace id. |
| **Data view** | A Kibana object that selects data streams by pattern (`logs-*-<id>`). It selects data; it never grants access. |

Workspace ids allow only `a-z`, `0-9` and `_` (a namespace can't contain
`-`), and never `default`.

## Status

This repository is being set up: the toolchain and the checks come first,
the module itself next.

## Getting started

Everything a contributor needs, from a clone, on Linux (Ubuntu or WSL2):

```bash
mise trust && mise install   # the pinned toolchain, git hooks, TFLint plugins
mise run check               # what CI runs
```

How a change flows, and the rules it follows:
[`CONTRIBUTING.md`](CONTRIBUTING.md).

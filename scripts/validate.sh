#!/usr/bin/env bash
# Credential-free: init without a backend, then validate the module and
# every example. Shared by `mise run validate` and CI.
set -euo pipefail
cd "$(dirname "$0")/.."

for d in . examples/*/; do
  echo "== ${d}"
  tofu -chdir="${d}" init -backend=false -input=false -no-color >/dev/null
  tofu -chdir="${d}" validate -no-color
done

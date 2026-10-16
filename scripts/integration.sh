#!/usr/bin/env bash
# Integration tests: the module against a real Elasticsearch + Kibana 9.5.4.
#
#   scripts/integration.sh          start the throwaway stack in Docker
#                                   (tests/integration/compose.yml), test,
#                                   remove it
#   IT_EXTERNAL_STACK=1 scripts/integration.sh
#                                   use a throwaway stack that's already
#                                   running: ELASTICSEARCH_ENDPOINTS,
#                                   KIBANA_ENDPOINT and ELASTICSEARCH_PASSWORD
#                                   (elastic's) set
#
# Two checks:
#   1. tofu test -test-directory=tests/integration: apply, assert, update,
#      destroy.
#   2. examples/self-managed: apply, then the plan must be empty (no drift
#      between what the module sends and what Elasticsearch and Kibana
#      return), then destroy.
#
# Never point it at a real cluster: it creates and destroys workspaces.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
example="$root/examples/self-managed"
compose=(docker compose -f "$root/tests/integration/compose.yml" --profile kibana)
started_stack=""
applied_example=""

cleanup() {
  if [ -n "$applied_example" ]; then
    tofu -chdir="$example" destroy -auto-approve -input=false >/dev/null || echo "WARN  destroying the example failed" >&2
    rm -f "$example"/terraform.tfstate "$example"/terraform.tfstate.backup
  fi
  if [ -n "$started_stack" ]; then
    "${compose[@]}" down --volumes
  fi
}
trap cleanup EXIT

if [ -z "${IT_EXTERNAL_STACK:-}" ]; then
  ELASTIC_PASSWORD=$(openssl rand -hex 16)
  KIBANA_SYSTEM_PASSWORD=$(openssl rand -hex 16)
  KIBANA_ENCRYPTION_KEY=$(openssl rand -hex 32)
  export ELASTIC_PASSWORD KIBANA_SYSTEM_PASSWORD KIBANA_ENCRYPTION_KEY

  echo "== starting Elasticsearch"
  started_stack=1
  "${compose[@]}" up --detach --wait elasticsearch
  curl -fsS -u "elastic:$ELASTIC_PASSWORD" -H 'Content-Type: application/json' \
    -d "{\"password\":\"$KIBANA_SYSTEM_PASSWORD\"}" \
    http://localhost:9200/_security/user/kibana_system/_password >/dev/null
  echo "== starting Kibana"
  "${compose[@]}" up --detach --wait kibana

  export ELASTICSEARCH_ENDPOINTS=http://localhost:9200
  export KIBANA_ENDPOINT=http://localhost:5601
  export ELASTICSEARCH_PASSWORD=$ELASTIC_PASSWORD
fi

# The provider reads these. elastic is the superuser of a throwaway stack.
export ELASTICSEARCH_USERNAME=elastic
export KIBANA_USERNAME=elastic
export KIBANA_PASSWORD=$ELASTICSEARCH_PASSWORD

echo "== tofu test (tests/integration)"
tofu -chdir="$root" init -backend=false -input=false >/dev/null
tofu -chdir="$root" test -test-directory=tests/integration

echo "== examples/self-managed: apply, no drift, destroy"
tofu -chdir="$example" init -input=false >/dev/null
applied_example=1
tofu -chdir="$example" apply -auto-approve -input=false
if tofu -chdir="$example" plan -detailed-exitcode -input=false; then
  echo "ok    no drift after apply"
else
  echo "FAIL  the plan after apply isn't empty (or failed)" >&2
  exit 1
fi

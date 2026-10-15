#!/usr/bin/env bash
# Integration test: throwaway single-node Elasticsearch + Kibana in Docker,
# then `tofu test` against them with the real provider (apply + destroy).
# Shared by `mise run test:integration` and CI.
#
# Usage: STACK_VERSION=9.1.0 scripts/integration.sh
set -euo pipefail
cd "$(dirname "$0")/.."

: "${STACK_VERSION:?set STACK_VERSION, e.g. 9.1.0}"
compose=(docker compose -f tests/integration/compose.yml -p workspace-it)

# Throwaway credentials, generated per run. Nothing is stored anywhere.
export ELASTIC_PASSWORD="${ELASTIC_PASSWORD:-$(openssl rand -hex 16)}"
export KIBANA_PASSWORD="${KIBANA_PASSWORD:-$(openssl rand -hex 16)}"
export KIBANA_ENCRYPTION_KEY="${KIBANA_ENCRYPTION_KEY:-$(openssl rand -hex 16)}"
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  echo "::add-mask::${ELASTIC_PASSWORD}"
  echo "::add-mask::${KIBANA_PASSWORD}"
  echo "::add-mask::${KIBANA_ENCRYPTION_KEY}"
fi

cleanup() {
  status=$?
  if [[ ${status} -ne 0 ]]; then "${compose[@]}" logs --tail=200 || true; fi
  "${compose[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  exit "${status}"
}
trap cleanup EXIT

"${compose[@]}" up -d --wait --wait-timeout 300

# Provider credentials via its standard env vars.
export ELASTICSEARCH_ENDPOINTS="http://localhost:9200"
export ELASTICSEARCH_USERNAME="elastic"
export ELASTICSEARCH_PASSWORD="${ELASTIC_PASSWORD}"
export KIBANA_ENDPOINT="http://localhost:5601"
export KIBANA_USERNAME="elastic"
export KIBANA_PASSWORD="${ELASTIC_PASSWORD}"

# Initialise Fleet once so the fleet_* resources have something to talk to.
curl -fsS -X POST -u "elastic:${ELASTIC_PASSWORD}" -H 'kbn-xsrf: true' \
  "${KIBANA_ENDPOINT}/api/fleet/setup" >/dev/null

tofu init -backend=false -input=false -no-color >/dev/null
tofu test -no-color -test-directory=tests/integration

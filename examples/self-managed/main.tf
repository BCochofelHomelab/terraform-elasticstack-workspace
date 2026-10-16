# One workspace on the homelab's self-managed Elastic Stack, the way a
# homelab-proxmox-platform workspace stack calls the module.

provider "elasticstack" {
  # Endpoints and credentials come from the environment, never from code:
  # ELASTICSEARCH_ENDPOINTS, ELASTICSEARCH_USERNAME/PASSWORD (or
  # ELASTICSEARCH_API_KEY), KIBANA_ENDPOINT, KIBANA_USERNAME/PASSWORD (or
  # KIBANA_API_KEY).
  elasticsearch {}
  kibana {}
}

module "workspace" {
  # A consumer pins a release by exact tag, without a "v":
  #   source = "git::https://github.com/BCochofelHomelab/terraform-elasticstack-workspace.git?ref=1.0.0"
  source = "../.."

  workspace_id = "otel_demo"
  display_name = "OpenTelemetry demo"
  description  = "The Astronomy Shop: its collector writes data_stream.namespace = otel_demo."
  color        = "#1EA593"

  data_types = ["logs", "metrics", "traces"]

  # Reads the stack's own telemetry too; the platform workspace's owner
  # approves this line.
  read_from = ["platform"]

  access = {
    # The homelab's SSO realm, as named in elasticsearch.yml. Leave it out
    # to match the groups from any realm.
    realm         = var.sso_realm
    viewer_groups = ["otel-demo-viewers"]
    editor_groups = ["otel-demo-editors"]
  }

  # The default alert destination. A connector with secrets (email,
  # authenticated webhook) is preconfigured in kibana.yml and referenced by
  # id; one without secrets can be created in the space. (On the basic
  # license, only .server-log and .index are available.)
  connectors = {
    server_log = { type = ".server-log", name = "Server log" }
  }
  alert_actions = [
    {
      connector = "server_log"
      params = jsonencode({
        level   = "warn"
        message = "[otel_demo] {{rule.name}}: {{context.reason}}{{context.message}}"
      })
    },
  ]

  # The workspace's own content, as the platform repo passes it: every
  # Kibana export in the workspace's folder.
  saved_objects = {
    for f in fileset("${path.module}/dashboards", "*.ndjson") : f => file("${path.module}/dashboards/${f}")
  }
}

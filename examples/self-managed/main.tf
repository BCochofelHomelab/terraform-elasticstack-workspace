# Homelab shape: basic license, native or OIDC realm. Alerts land in the
# workspace's alerts index; workspace dashboards are *.ndjson files next to
# the stack.
module "workspace" {
  source = "../.."

  workspace   = var.workspace
  owner       = "sre"
  description = "OpenTelemetry Astronomy Shop demo"
  read_from   = ["platform"]

  access = {
    bindings = { "homelab-admins" = "editor" }
  }

  extra_saved_objects = {
    for f in fileset("${path.module}/dashboards", "*.ndjson") :
    trimsuffix(f, ".ndjson") => file("${path.module}/dashboards/${f}")
  }
}

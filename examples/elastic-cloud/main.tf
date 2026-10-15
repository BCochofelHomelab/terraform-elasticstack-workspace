# Elastic Cloud shape: OIDC groups from the identity provider, and a
# ServiceNow connector as the default alert destination. Same module, only
# inputs differ.
module "workspace" {
  source = "../.."

  workspace         = var.workspace
  owner             = "payments-platform"
  description       = "Payments services"
  color             = "#1BA9F5"
  solution          = "oblt"
  disabled_features = ["siem"]

  access = {
    realm = "oidc-entra" # placeholder: the deployment's OIDC realm name
    bindings = {
      "grp-payments-engineers" = "editor"
      "grp-payments-support"   = "viewer"
    }
  }

  alerting = {
    destinations = [{
      connector_id = var.servicenow_connector_id
      params = {
        subAction = "pushToService"
        subActionParams = {
          incident = {
            short_description = "{{rule.name}}: {{context.title}}"
            description       = "{{context.message}}"
          }
        }
      }
    }]
  }

  rules = {
    checkout_errors = {
      query     = { query = { bool = { filter = [{ match = { "service.name" = "checkout" } }, { match = { "log.level" = "error" } }] } } }
      threshold = 10
    }
  }
}

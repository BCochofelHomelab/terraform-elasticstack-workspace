terraform {
  required_version = ">= 1.8.0"

  required_providers {
    elasticstack = {
      source = "elastic/elasticstack"
      # A real root configuration pins tighter than the module and commits
      # its .terraform.lock.hcl.
      version = ">= 0.16.0, < 1.0.0"
    }
  }
}

# Endpoints and API key from the environment, never from tfvars:
#   ELASTICSEARCH_ENDPOINTS, ELASTICSEARCH_API_KEY, KIBANA_ENDPOINT, KIBANA_API_KEY
provider "elasticstack" {
  elasticsearch {}
  kibana {}
}

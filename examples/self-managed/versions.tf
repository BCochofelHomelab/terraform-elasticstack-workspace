terraform {
  required_version = ">= 1.8.0"

  required_providers {
    elasticstack = {
      source  = "elastic/elasticstack"
      version = ">= 0.16.5, < 1.0.0"
    }
  }
}

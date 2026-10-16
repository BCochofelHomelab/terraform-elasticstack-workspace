terraform {
  # mock_provider (tofu test) and the provider's own minimum.
  required_version = ">= 1.8.0"

  required_providers {
    # The upper bound is deliberate while the provider is pre-1.0: a 0.x
    # minor may break, and the module must not pick one up untested.
    elasticstack = {
      source  = "elastic/elasticstack"
      version = ">= 0.16.5, < 1.0.0"
    }
  }
}

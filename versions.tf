terraform {
  # 1.8+ for mock_provider in tofu test. CI runs the version pinned in
  # mise.toml; consumers can run anything from this floor up.
  required_version = ">= 1.8.0"

  required_providers {
    elasticstack = {
      source = "elastic/elasticstack"
      # Floor = the provider version this module is validated and tested
      # against. Upper bound on purpose while the provider is pre-1.0
      # (CLAUDE.md): a reusable module normally sets a minimum only.
      version = ">= 0.16.0, < 1.0.0"
    }
  }
}

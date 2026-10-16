variable "sso_realm" {
  description = "The SSO realm's name in elasticsearch.yml (`xpack.security.authc.realms.oidc.<name>`). Null matches groups from any realm."
  type        = string
  default     = null
}

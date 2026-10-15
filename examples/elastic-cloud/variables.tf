variable "workspace" {
  description = "Workspace to create."
  type        = string
  default     = "payments"
}

variable "servicenow_connector_id" {
  description = "Id of an existing ServiceNow connector (preconfigured on the deployment, or managed in the platform repo)."
  type        = string
  default     = "servicenow-itsm" # placeholder
}

variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for BigQuery datasets"
  type        = string
  default     = "asia-northeast1"
}

variable "environments" {
  description = "List of environments (dev, prod)"
  type        = list(string)
  default     = ["dev", "prod"]
}

variable "alert_recipient_email" {
  description = "Recipient email address for Dataform alert notifications"
  type        = string
}

variable "github_repository_url" {
  description = "GitHub repository URL for Dataform (e.g., https://github.com/owner/repo.git)"
  type        = string
}

variable "github_token" {
  description = "GitHub Personal Access Token for Dataform repository access"
  type        = string
  sensitive   = true
}

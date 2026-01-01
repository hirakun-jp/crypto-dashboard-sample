################################################################################
# GitHub Token (for Dataform Git integration)
################################################################################

resource "google_secret_manager_secret" "github_token" {
  secret_id = "dataform-github-token"
  project   = var.gcp_project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "github_token" {
  secret      = google_secret_manager_secret.github_token.id
  secret_data = var.github_token

  lifecycle {
    ignore_changes = [secret_data]
  }
}

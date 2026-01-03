################################################################################
# Repository
################################################################################

resource "google_dataform_repository" "hyperliquid" {
  provider        = google-beta
  name            = "hyperliquid-dataform"
  region          = var.gcp_region
  project         = var.gcp_project_id
  service_account = google_service_account.dataform.email

  git_remote_settings {
    url                                 = var.github_repository_url
    default_branch                      = "main"
    authentication_token_secret_version = google_secret_manager_secret_version.github_token.id
  }

  workspace_compilation_overrides {
    default_database = var.gcp_project_id
    schema_suffix    = "dev"
  }

  depends_on = [google_project_service.required_apis]
}

################################################################################
# Release Config (prod)
################################################################################

resource "google_dataform_repository_release_config" "prod" {
  provider   = google-beta
  project    = var.gcp_project_id
  region     = var.gcp_region
  repository = google_dataform_repository.hyperliquid.name
  name       = "prod"

  git_commitish = "main"

  code_compilation_config {
    default_database = var.gcp_project_id
    vars = {
      environment    = "prod"
      gcp_project_id = var.gcp_project_id
    }
  }
}

################################################################################
# Workflow Config (prod - scheduled execution)
################################################################################

resource "google_dataform_repository_workflow_config" "prod" {
  provider       = google-beta
  project        = var.gcp_project_id
  region         = var.gcp_region
  repository     = google_dataform_repository.hyperliquid.name
  name           = "prod"
  release_config = google_dataform_repository_release_config.prod.id

  invocation_config {
    transitive_dependencies_included = true
  }

  cron_schedule = "0 3 * * *"
  time_zone     = "Asia/Tokyo"
}

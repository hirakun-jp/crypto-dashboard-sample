################################################################################
# Cloud Build (for Cloud Functions Gen2)
################################################################################

data "google_project" "current" {
  project_id = var.gcp_project_id
}

resource "google_project_iam_member" "cloudbuild_logs_writer" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_storage_viewer" {
  project = var.gcp_project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_artifact_registry" {
  project = var.gcp_project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

################################################################################
# Cloud Functions (API → BigQuery)
################################################################################

resource "google_service_account" "cloud_functions" {
  account_id   = "cf-ingest-hyperliquid"
  display_name = "Cloud Functions - HyperLiquid Ingestion"
  description  = "Service account for Cloud Functions to ingest HyperLiquid data"
  project      = var.gcp_project_id
}

resource "google_project_iam_member" "cf_bigquery_job" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.cloud_functions.email}"
}

resource "google_bigquery_dataset_iam_member" "cf_sources_editor" {
  dataset_id = google_bigquery_dataset.sources.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.cloud_functions.email}"
  project    = var.gcp_project_id
}

################################################################################
# Cloud Scheduler (Functions invoke)
################################################################################

resource "google_service_account" "cloud_scheduler" {
  account_id   = "scheduler-ingest-hyperliquid"
  display_name = "Cloud Scheduler - HyperLiquid Ingestion"
  description  = "Service account for Cloud Scheduler to invoke Cloud Functions"
  project      = var.gcp_project_id
}

resource "google_cloudfunctions2_function_iam_member" "scheduler_invoker" {
  for_each = toset(var.environments)

  project        = var.gcp_project_id
  location       = var.gcp_region
  cloud_function = google_cloudfunctions2_function.ingest_hyperliquid[each.value].name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.cloud_scheduler.email}"
}

resource "google_cloud_run_service_iam_member" "scheduler_invoker" {
  for_each = toset(var.environments)

  project  = var.gcp_project_id
  location = var.gcp_region
  service  = google_cloudfunctions2_function.ingest_hyperliquid[each.value].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cloud_scheduler.email}"
}

################################################################################
# Dataform (SQL Workflow)
################################################################################

resource "google_service_account" "dataform" {
  account_id   = "dataform-hyperliquid"
  display_name = "Dataform Service Account for HyperLiquid"
  description  = "Service account for Dataform to execute SQL workflows"
  project      = var.gcp_project_id
}

resource "google_project_iam_member" "dataform_bigquery" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.dataform.email}"
}

resource "google_bigquery_dataset_iam_member" "dataform_sources_viewer" {
  dataset_id = google_bigquery_dataset.sources.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.dataform.email}"
  project    = var.gcp_project_id
}

resource "google_bigquery_dataset_iam_member" "dataform_staging_editor" {
  for_each = toset(var.environments)

  dataset_id = google_bigquery_dataset.staging[each.value].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.dataform.email}"
  project    = var.gcp_project_id
}

resource "google_bigquery_dataset_iam_member" "dataform_intermediate_editor" {
  for_each = toset(var.environments)

  dataset_id = google_bigquery_dataset.intermediate[each.value].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.dataform.email}"
  project    = var.gcp_project_id
}

resource "google_bigquery_dataset_iam_member" "dataform_marts_analytics_editor" {
  for_each = toset(var.environments)

  dataset_id = google_bigquery_dataset.marts_analytics[each.value].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.dataform.email}"
  project    = var.gcp_project_id
}

resource "google_bigquery_dataset_iam_member" "dataform_marts_shared_editor" {
  for_each = toset(var.environments)

  dataset_id = google_bigquery_dataset.marts_shared[each.value].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.dataform.email}"
  project    = var.gcp_project_id
}

resource "google_secret_manager_secret_iam_member" "dataform_github_token" {
  secret_id = google_secret_manager_secret.github_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.dataform.email}"
}

################################################################################
# Looker Studio (BI)
################################################################################

resource "google_service_account" "looker_studio" {
  account_id   = "looker-studio-viewer"
  display_name = "Looker Studio Viewer"
  description  = "Service account for Looker Studio to query marts layer"
  project      = var.gcp_project_id
}

resource "google_project_iam_member" "looker_studio_bigquery" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.looker_studio.email}"
}

resource "google_bigquery_dataset_iam_member" "looker_studio_marts_analytics_viewer" {
  for_each = toset(var.environments)

  dataset_id = google_bigquery_dataset.marts_analytics[each.value].dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.looker_studio.email}"
  project    = var.gcp_project_id
}

resource "google_bigquery_dataset_iam_member" "looker_studio_marts_shared_viewer" {
  for_each = toset(var.environments)

  dataset_id = google_bigquery_dataset.marts_shared[each.value].dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.looker_studio.email}"
  project    = var.gcp_project_id
}

################################################################################
# User IAM (Template - Uncomment and customize for production)
################################################################################
#
# Recommended: Use Google Groups for role-based access control
#
# variable "data_engineer_group" {
#   description = "Google Group for data engineers"
#   type        = string
#   default     = "data-engineers@your-domain.com"
# }
#
# variable "internal_analyst_group" {
#   description = "Google Group for internal data analysts"
#   type        = string
#   default     = "data-analysts@your-domain.com"
# }
#
# variable "external_analyst_group" {
#   description = "Google Group for external/contractor analysts (no sources access)"
#   type        = string
#   default     = "external-analysts@your-domain.com"
# }
#
# variable "business_user_group" {
#   description = "Google Group for business users (marts only)"
#   type        = string
#   default     = "business-users@your-domain.com"
# }
#
# ----------------------------------------
# Data Engineer: Full access to all layers
# ----------------------------------------
# resource "google_project_iam_member" "engineer_job_user" {
#   project = var.gcp_project_id
#   role    = "roles/bigquery.jobUser"
#   member  = "group:${var.data_engineer_group}"
# }
#
# resource "google_project_iam_member" "engineer_dataform_admin" {
#   project = var.gcp_project_id
#   role    = "roles/dataform.admin"
#   member  = "group:${var.data_engineer_group}"
# }
#
# ----------------------------------------
# Internal Analyst: sources(Viewer), stg/int/mart(Editor)
# ----------------------------------------
# resource "google_project_iam_member" "internal_analyst_job_user" {
#   project = var.gcp_project_id
#   role    = "roles/bigquery.jobUser"
#   member  = "group:${var.internal_analyst_group}"
# }
#
# resource "google_project_iam_member" "internal_analyst_dataform" {
#   project = var.gcp_project_id
#   role    = "roles/dataform.editor"
#   member  = "group:${var.internal_analyst_group}"
# }
#
# resource "google_bigquery_dataset_iam_member" "internal_analyst_sources_viewer" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.sources[each.value].dataset_id
#   role       = "roles/bigquery.dataViewer"
#   member     = "group:${var.internal_analyst_group}"
#   project    = var.gcp_project_id
# }
#
# ----------------------------------------
# External Analyst: NO sources access, stg(Viewer), int/mart(Editor)
# ----------------------------------------
# resource "google_project_iam_member" "external_analyst_job_user" {
#   project = var.gcp_project_id
#   role    = "roles/bigquery.jobUser"
#   member  = "group:${var.external_analyst_group}"
# }
#
# resource "google_project_iam_member" "external_analyst_dataform" {
#   project = var.gcp_project_id
#   role    = "roles/dataform.editor"
#   member  = "group:${var.external_analyst_group}"
# }
#
# resource "google_bigquery_dataset_iam_member" "external_analyst_staging_viewer" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.staging[each.value].dataset_id
#   role       = "roles/bigquery.dataViewer"
#   member     = "group:${var.external_analyst_group}"
#   project    = var.gcp_project_id
# }
#
# resource "google_bigquery_dataset_iam_member" "external_analyst_intermediate_editor" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.intermediate[each.value].dataset_id
#   role       = "roles/bigquery.dataEditor"
#   member     = "group:${var.external_analyst_group}"
#   project    = var.gcp_project_id
# }
#
# ----------------------------------------
# Business User: marts(Viewer) only
# ----------------------------------------
# resource "google_project_iam_member" "business_user_job_user" {
#   project = var.gcp_project_id
#   role    = "roles/bigquery.jobUser"
#   member  = "group:${var.business_user_group}"
# }
#
# resource "google_bigquery_dataset_iam_member" "business_user_marts_analytics_viewer" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.marts_analytics[each.value].dataset_id
#   role       = "roles/bigquery.dataViewer"
#   member     = "group:${var.business_user_group}"
#   project    = var.gcp_project_id
# }

################################################################################
# Cloud Build (for Cloud Functions Gen2)
################################################################################

data "google_project" "current" {
  project_id = var.gcp_project_id
}

resource "google_service_account" "functions_cloudbuild_sa" {
  account_id   = "functions-cloudbuild-sa"
  display_name = "Cloud Build - Functions Build"
  description  = "Service account for building Cloud Functions Gen2"
  project      = var.gcp_project_id
}

resource "google_project_iam_member" "functions_cloudbuild_sa_builder" {
  project = var.gcp_project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.functions_cloudbuild_sa.email}"
}

resource "google_project_iam_member" "functions_cloudbuild_sa_artifact_registry_writer" {
  project = var.gcp_project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.functions_cloudbuild_sa.email}"
}

resource "google_project_iam_member" "functions_cloudbuild_sa_run_admin" {
  project = var.gcp_project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.functions_cloudbuild_sa.email}"
}

resource "google_project_iam_member" "functions_cloudbuild_sa_service_account_user" {
  project = var.gcp_project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.functions_cloudbuild_sa.email}"
}

resource "google_project_iam_member" "functions_cloudbuild_sa_logs_writer" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.functions_cloudbuild_sa.email}"
}

resource "google_project_iam_member" "functions_cloudbuild_sa_storage_viewer" {
  project = var.gcp_project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.functions_cloudbuild_sa.email}"
}

resource "time_sleep" "wait_for_cloudbuild_iam" {
  depends_on = [
    google_service_account.functions_cloudbuild_sa,
    google_project_iam_member.functions_cloudbuild_sa_builder,
    google_project_iam_member.functions_cloudbuild_sa_artifact_registry_writer,
    google_project_iam_member.functions_cloudbuild_sa_run_admin,
    google_project_iam_member.functions_cloudbuild_sa_service_account_user,
    google_project_iam_member.functions_cloudbuild_sa_logs_writer,
    google_project_iam_member.functions_cloudbuild_sa_storage_viewer,
  ]
  create_duration = "120s"
}

################################################################################
# Cloud Functions (API → BigQuery)
################################################################################

resource "google_service_account" "hyperliquid_ingest_function_sa" {
  account_id   = "hyperliquid-ingest-function-sa"
  display_name = "Cloud Functions - HyperLiquid Ingestion"
  description  = "Service account for Cloud Functions to ingest HyperLiquid data"
  project      = var.gcp_project_id
}

resource "google_project_iam_member" "hyperliquid_ingest_function_sa_bigquery_job_user" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.hyperliquid_ingest_function_sa.email}"
}

resource "google_bigquery_dataset_iam_member" "hyperliquid_ingest_function_sa_sources_editor" {
  dataset_id = google_bigquery_dataset.sources.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.hyperliquid_ingest_function_sa.email}"
  project    = var.gcp_project_id
}

################################################################################
# Cloud Scheduler (Functions invoke)
################################################################################

resource "google_service_account" "hyperliquid_ingest_daily_scheduler_sa" {
  account_id   = "hl-ingest-daily-scheduler-sa"
  display_name = "Cloud Scheduler - HyperLiquid Ingestion"
  description  = "Service account for Cloud Scheduler to invoke Cloud Functions"
  project      = var.gcp_project_id
}

resource "google_cloudfunctions2_function_iam_member" "hyperliquid_ingest_daily_scheduler_sa_invoker" {
  for_each = toset(var.environments)

  project        = var.gcp_project_id
  location       = var.gcp_region
  cloud_function = google_cloudfunctions2_function.hyperliquid_ingest_function[each.value].name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.hyperliquid_ingest_daily_scheduler_sa.email}"
}

resource "google_cloud_run_service_iam_member" "hyperliquid_ingest_daily_scheduler_sa_run_invoker" {
  for_each = toset(var.environments)

  project  = var.gcp_project_id
  location = var.gcp_region
  service  = google_cloudfunctions2_function.hyperliquid_ingest_function[each.value].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.hyperliquid_ingest_daily_scheduler_sa.email}"
}

################################################################################
# Dataform (SQL Workflow)
################################################################################

resource "google_service_account" "analytics_dataform_sa" {
  account_id   = "analytics-dataform-sa"
  display_name = "Dataform Service Account"
  description  = "Service account for Dataform to execute SQL workflows (multi-domain)"
  project      = var.gcp_project_id
}

resource "google_project_iam_member" "analytics_dataform_sa_bigquery_user" {
  project = var.gcp_project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.analytics_dataform_sa.email}"
}

resource "google_project_iam_member" "analytics_dataform_sa_bigquery_job_user" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.analytics_dataform_sa.email}"
}

resource "google_bigquery_dataset_iam_member" "analytics_dataform_sa_sources_viewer" {
  dataset_id = google_bigquery_dataset.sources.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.analytics_dataform_sa.email}"
  project    = var.gcp_project_id
}

resource "google_bigquery_dataset_iam_member" "analytics_dataform_sa_staging_editor" {
  for_each = toset(var.environments)

  dataset_id = google_bigquery_dataset.staging[each.value].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.analytics_dataform_sa.email}"
  project    = var.gcp_project_id
}

resource "google_bigquery_dataset_iam_member" "analytics_dataform_sa_intermediate_editor" {
  for_each = toset(var.environments)

  dataset_id = google_bigquery_dataset.intermediate[each.value].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.analytics_dataform_sa.email}"
  project    = var.gcp_project_id
}

resource "google_bigquery_dataset_iam_member" "analytics_dataform_sa_marts_analytics_editor" {
  for_each = toset(var.environments)

  dataset_id = google_bigquery_dataset.marts_analytics[each.value].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.analytics_dataform_sa.email}"
  project    = var.gcp_project_id
}

resource "google_bigquery_dataset_iam_member" "analytics_dataform_sa_marts_shared_editor" {
  for_each = toset(var.environments)

  dataset_id = google_bigquery_dataset.marts_shared[each.value].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.analytics_dataform_sa.email}"
  project    = var.gcp_project_id
}

resource "google_secret_manager_secret_iam_member" "analytics_dataform_sa_github_token" {
  secret_id = google_secret_manager_secret.github_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.analytics_dataform_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "dataform_default_sa_github_token" {
  secret_id = google_secret_manager_secret.github_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-dataform.iam.gserviceaccount.com"
}

resource "google_service_account_iam_member" "analytics_dataform_sa_token_creator" {
  service_account_id = google_service_account.analytics_dataform_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-dataform.iam.gserviceaccount.com"
}

resource "google_service_account_iam_member" "analytics_dataform_sa_user" {
  service_account_id = google_service_account.analytics_dataform_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-dataform.iam.gserviceaccount.com"
}

################################################################################
# Looker Studio (BI)
################################################################################

resource "google_service_account" "analytics_looker_studio_sa" {
  account_id   = "analytics-looker-studio-sa"
  display_name = "Looker Studio Viewer"
  description  = "Service account for Looker Studio to query marts layer (multi-domain)"
  project      = var.gcp_project_id
}

resource "google_project_iam_member" "analytics_looker_studio_sa_bigquery_job_user" {
  project = var.gcp_project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.analytics_looker_studio_sa.email}"
}

resource "google_bigquery_dataset_iam_member" "analytics_looker_studio_sa_marts_analytics_viewer" {
  for_each = toset(var.environments)

  dataset_id = google_bigquery_dataset.marts_analytics[each.value].dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.analytics_looker_studio_sa.email}"
  project    = var.gcp_project_id
}

resource "google_bigquery_dataset_iam_member" "analytics_looker_studio_sa_marts_shared_viewer" {
  for_each = toset(var.environments)

  dataset_id = google_bigquery_dataset.marts_shared[each.value].dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.analytics_looker_studio_sa.email}"
  project    = var.gcp_project_id
}

resource "google_service_account_iam_member" "analytics_looker_studio_sa_token_creator" {
  service_account_id = google_service_account.analytics_looker_studio_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-org-${var.gcp_org_id}@gcp-sa-datastudio.iam.gserviceaccount.com"
}

################################################################################
# User IAM (Template - Uncomment and customize for production)
################################################################################
#
# Recommended: Use Google Groups for role-based access control
#
# Permission Matrix (from README):
# | Role                   | sources | staging | intermediate | marts | Dataform |
# |------------------------|---------|---------|--------------|-------|----------|
# | Data Engineer          | Editor  | Editor  | Editor       | Editor| Admin    |
# | Internal Analyst       | Viewer  | Viewer  | Editor       | Editor| Editor   |
# | External Analyst       | -       | Viewer  | Editor       | Editor| Editor   |
# | Business User          | -       | -       | -            | Viewer| -        |
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
# Data Engineer: Full Editor access to all layers + Dataform Admin
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
# resource "google_service_account_iam_member" "engineer_dataform_sa_user" {
#   service_account_id = google_service_account.analytics_dataform_sa.name
#   role               = "roles/iam.serviceAccountUser"
#   member             = "group:${var.data_engineer_group}"
# }
#
# resource "google_bigquery_dataset_iam_member" "engineer_sources_editor" {
#   dataset_id = google_bigquery_dataset.sources.dataset_id
#   role       = "roles/bigquery.dataEditor"
#   member     = "group:${var.data_engineer_group}"
#   project    = var.gcp_project_id
# }
#
# resource "google_bigquery_dataset_iam_member" "engineer_staging_editor" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.staging[each.value].dataset_id
#   role       = "roles/bigquery.dataEditor"
#   member     = "group:${var.data_engineer_group}"
#   project    = var.gcp_project_id
# }
#
# resource "google_bigquery_dataset_iam_member" "engineer_intermediate_editor" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.intermediate[each.value].dataset_id
#   role       = "roles/bigquery.dataEditor"
#   member     = "group:${var.data_engineer_group}"
#   project    = var.gcp_project_id
# }
#
# resource "google_bigquery_dataset_iam_member" "engineer_marts_analytics_editor" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.marts_analytics[each.value].dataset_id
#   role       = "roles/bigquery.dataEditor"
#   member     = "group:${var.data_engineer_group}"
#   project    = var.gcp_project_id
# }
#
# resource "google_bigquery_dataset_iam_member" "engineer_marts_shared_editor" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.marts_shared[each.value].dataset_id
#   role       = "roles/bigquery.dataEditor"
#   member     = "group:${var.data_engineer_group}"
#   project    = var.gcp_project_id
# }
#
# ----------------------------------------
# Internal Analyst: sources(Viewer), staging(Viewer), int/mart(Editor), Dataform(Editor)
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
# resource "google_service_account_iam_member" "internal_analyst_dataform_sa_user" {
#   service_account_id = google_service_account.analytics_dataform_sa.name
#   role               = "roles/iam.serviceAccountUser"
#   member             = "group:${var.internal_analyst_group}"
# }
#
# resource "google_bigquery_dataset_iam_member" "internal_analyst_sources_viewer" {
#   dataset_id = google_bigquery_dataset.sources.dataset_id
#   role       = "roles/bigquery.dataViewer"
#   member     = "group:${var.internal_analyst_group}"
#   project    = var.gcp_project_id
# }
#
# resource "google_bigquery_dataset_iam_member" "internal_analyst_staging_viewer" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.staging[each.value].dataset_id
#   role       = "roles/bigquery.dataViewer"
#   member     = "group:${var.internal_analyst_group}"
#   project    = var.gcp_project_id
# }
#
# resource "google_bigquery_dataset_iam_member" "internal_analyst_intermediate_editor" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.intermediate[each.value].dataset_id
#   role       = "roles/bigquery.dataEditor"
#   member     = "group:${var.internal_analyst_group}"
#   project    = var.gcp_project_id
# }
#
# resource "google_bigquery_dataset_iam_member" "internal_analyst_marts_analytics_editor" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.marts_analytics[each.value].dataset_id
#   role       = "roles/bigquery.dataEditor"
#   member     = "group:${var.internal_analyst_group}"
#   project    = var.gcp_project_id
# }
#
# resource "google_bigquery_dataset_iam_member" "internal_analyst_marts_shared_editor" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.marts_shared[each.value].dataset_id
#   role       = "roles/bigquery.dataEditor"
#   member     = "group:${var.internal_analyst_group}"
#   project    = var.gcp_project_id
# }
#
# ----------------------------------------
# External Analyst: NO sources, staging(Viewer), int/mart(Editor), Dataform(Editor)
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
# resource "google_service_account_iam_member" "external_analyst_dataform_sa_user" {
#   service_account_id = google_service_account.analytics_dataform_sa.name
#   role               = "roles/iam.serviceAccountUser"
#   member             = "group:${var.external_analyst_group}"
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
# resource "google_bigquery_dataset_iam_member" "external_analyst_marts_analytics_editor" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.marts_analytics[each.value].dataset_id
#   role       = "roles/bigquery.dataEditor"
#   member     = "group:${var.external_analyst_group}"
#   project    = var.gcp_project_id
# }
#
# resource "google_bigquery_dataset_iam_member" "external_analyst_marts_shared_editor" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.marts_shared[each.value].dataset_id
#   role       = "roles/bigquery.dataEditor"
#   member     = "group:${var.external_analyst_group}"
#   project    = var.gcp_project_id
# }
#
# ----------------------------------------
# Business User: marts(Viewer) only + Looker Studio SA access
# (No Dataform access, but needs serviceAccountUser for Looker Studio data source creation)
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
#
# resource "google_bigquery_dataset_iam_member" "business_user_marts_shared_viewer" {
#   for_each   = toset(var.environments)
#   dataset_id = google_bigquery_dataset.marts_shared[each.value].dataset_id
#   role       = "roles/bigquery.dataViewer"
#   member     = "group:${var.business_user_group}"
#   project    = var.gcp_project_id
# }
#
# resource "google_service_account_iam_member" "business_user_looker_studio_sa_user" {
#   service_account_id = google_service_account.analytics_looker_studio_sa.name
#   role               = "roles/iam.serviceAccountUser"
#   member             = "group:${var.business_user_group}"
# }

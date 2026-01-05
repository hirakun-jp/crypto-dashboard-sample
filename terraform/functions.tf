################################################################################
# Cloud Run Functions - HyperLiquid Data Ingestion
################################################################################

resource "google_storage_bucket" "functions_source" {
  name                        = "${var.gcp_project_id}-functions-source"
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  force_destroy               = true
}

data "archive_file" "hyperliquid_ingest_function" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/ingest_hyperliquid"
  output_path = "${path.module}/../.build/ingest_hyperliquid.zip"
}

resource "google_storage_bucket_object" "hyperliquid_ingest_function" {
  name   = "hyperliquid-ingest-function-${data.archive_file.hyperliquid_ingest_function.output_md5}.zip"
  bucket = google_storage_bucket.functions_source.name
  source = data.archive_file.hyperliquid_ingest_function.output_path
}

resource "google_cloudfunctions2_function" "hyperliquid_ingest_function" {
  for_each = toset(var.environments)

  name     = each.value == "prod" ? "hyperliquid-ingest-function" : "hyperliquid-ingest-function-${each.value}"
  location = var.gcp_region
  project  = var.gcp_project_id

  build_config {
    runtime         = "python312"
    entry_point     = "ingest_hyperliquid"
    service_account = google_service_account.functions_cloudbuild_sa.id
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.hyperliquid_ingest_function.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = "512M"
    timeout_seconds       = 300
    service_account_email = google_service_account.hyperliquid_ingest_function_sa.email

    environment_variables = {
      GCP_PROJECT_ID = var.gcp_project_id
      BQ_DATASET_ID  = "src_hyperliquid"
    }
  }

  depends_on = [
    google_project_service.required_apis,
    time_sleep.wait_for_cloudbuild_iam,
  ]
}

################################################################################
# Cloud Scheduler - Daily 02:00 JST
################################################################################

resource "google_cloud_scheduler_job" "hyperliquid_ingest_daily_scheduler" {
  name        = "hyperliquid-ingest-daily-scheduler"
  description = "Trigger HyperLiquid data ingestion daily at 02:00 JST"
  schedule    = "0 2 * * *"
  time_zone   = "Asia/Tokyo"
  project     = var.gcp_project_id
  region      = var.gcp_region

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.hyperliquid_ingest_function["prod"].url

    oidc_token {
      service_account_email = google_service_account.hyperliquid_ingest_daily_scheduler_sa.email
    }
  }

  depends_on = [
    google_project_service.required_apis,
  ]
}

################################################################################
# Cloud Run Functions - HyperLiquid Data Ingestion
################################################################################

resource "google_storage_bucket" "functions_source" {
  name                        = "${var.gcp_project_id}-functions-source"
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  force_destroy               = true
}

data "archive_file" "ingest_hyperliquid" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/ingest_hyperliquid"
  output_path = "${path.module}/../.build/ingest_hyperliquid.zip"
}

resource "google_storage_bucket_object" "ingest_hyperliquid" {
  name   = "ingest_hyperliquid-${data.archive_file.ingest_hyperliquid.output_md5}.zip"
  bucket = google_storage_bucket.functions_source.name
  source = data.archive_file.ingest_hyperliquid.output_path
}

resource "google_cloudfunctions2_function" "ingest_hyperliquid" {
  for_each = toset(var.environments)

  name     = each.value == "prod" ? "ingest-hyperliquid" : "ingest-hyperliquid-${each.value}"
  location = var.gcp_region
  project  = var.gcp_project_id

  build_config {
    runtime     = "python312"
    entry_point = "ingest_hyperliquid"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.ingest_hyperliquid.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = "512M"
    timeout_seconds       = 300
    service_account_email = google_service_account.cloud_functions.email

    environment_variables = {
      GCP_PROJECT_ID = var.gcp_project_id
      BQ_DATASET_ID  = "src_hyperliquid"
    }
  }

  depends_on = [
    google_project_service.required_apis,
  ]
}

################################################################################
# Cloud Scheduler - Daily 02:00 JST
################################################################################

resource "google_cloud_scheduler_job" "ingest_hyperliquid" {
  name        = "ingest-hyperliquid-daily"
  description = "Trigger HyperLiquid data ingestion daily at 02:00 JST"
  schedule    = "0 2 * * *"
  time_zone   = "Asia/Tokyo"
  project     = var.gcp_project_id
  region      = var.gcp_region

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.ingest_hyperliquid["prod"].url

    oidc_token {
      service_account_email = google_service_account.cloud_scheduler.email
    }
  }

  depends_on = [
    google_project_service.required_apis,
  ]
}

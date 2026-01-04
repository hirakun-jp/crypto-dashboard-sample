################################################################################
# Sources Layer (Cloud Functions writes here)
################################################################################

resource "google_bigquery_dataset" "sources" {
  dataset_id  = "src_hyperliquid"
  project     = var.gcp_project_id
  location    = var.gcp_region
  description = "HyperLiquid raw data from API"

  labels = {
    environment = "prod"
    layer       = "sources"
    managed_by  = "terraform"
  }
}

resource "google_bigquery_table" "candle_1h" {
  dataset_id          = google_bigquery_dataset.sources.dataset_id
  table_id            = "candle_1h"
  project             = var.gcp_project_id
  deletion_protection = true
  description         = "HyperLiquid 1-hour candle data (BTC, ETH, DOGE)"

  schema = jsonencode([
    { name = "time", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "open", type = "FLOAT", mode = "NULLABLE" },
    { name = "high", type = "FLOAT", mode = "NULLABLE" },
    { name = "low", type = "FLOAT", mode = "NULLABLE" },
    { name = "close", type = "FLOAT", mode = "NULLABLE" },
    { name = "volume", type = "FLOAT", mode = "NULLABLE" },
    { name = "num_trades", type = "INTEGER", mode = "NULLABLE" },
    { name = "symbol", type = "STRING", mode = "NULLABLE" },
    { name = "updated_at", type = "TIMESTAMP", mode = "NULLABLE" },
  ])

  labels = {
    layer      = "sources"
    managed_by = "terraform"
  }
}

################################################################################
# Staging Layer (Column normalization)
################################################################################

resource "google_bigquery_dataset" "staging" {
  for_each = toset(var.environments)

  dataset_id  = each.value == "prod" ? "stg_hyperliquid" : "stg_hyperliquid_${each.value}"
  project     = var.gcp_project_id
  location    = var.gcp_region
  description = "Staging layer for column normalization (${each.value} environment)"

  labels = {
    environment = each.value
    layer       = "staging"
    managed_by  = "terraform"
  }
}

################################################################################
# Intermediate Layer (Business logic)
################################################################################

resource "google_bigquery_dataset" "intermediate" {
  for_each = toset(var.environments)

  dataset_id  = each.value == "prod" ? "int_coin_trend" : "int_coin_trend_${each.value}"
  project     = var.gcp_project_id
  location    = var.gcp_region
  description = "Intermediate layer for multi-coin trend comparison (${each.value} environment)"

  labels = {
    environment = each.value
    layer       = "intermediate"
    managed_by  = "terraform"
  }
}

################################################################################
# Marts Layer (BI consumption)
################################################################################

resource "google_bigquery_dataset" "marts_analytics" {
  for_each = toset(var.environments)

  dataset_id  = each.value == "prod" ? "mart_coin_trend" : "mart_coin_trend_${each.value}"
  project     = var.gcp_project_id
  location    = var.gcp_region
  description = "Mart for multi-coin trend comparison BI (${each.value} environment)"

  labels = {
    environment = each.value
    layer       = "marts"
    managed_by  = "terraform"
  }
}

resource "google_bigquery_dataset" "marts_shared" {
  for_each = toset(var.environments)

  dataset_id  = each.value == "prod" ? "mart_shared" : "mart_shared_${each.value}"
  project     = var.gcp_project_id
  location    = var.gcp_region
  description = "Shared conformed dimensions (${each.value} environment)"

  labels = {
    environment = each.value
    layer       = "marts"
    managed_by  = "terraform"
  }
}

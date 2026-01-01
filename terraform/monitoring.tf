################################################################################
# Required APIs for Monitoring
################################################################################

resource "google_project_service" "logging_api" {
  project            = var.gcp_project_id
  service            = "logging.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "monitoring_api" {
  project            = var.gcp_project_id
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

################################################################################
# Log-based Metric (Dataform failures)
################################################################################

resource "google_logging_metric" "dataform_failures" {
  project = var.gcp_project_id
  name    = "dataform-workflow-failures"

  filter = <<-EOT
    resource.type="dataform.googleapis.com/Repository"
    jsonPayload.@type="type.googleapis.com/google.cloud.dataform.logging.v1.WorkflowInvocationCompletionLogEntry"
    jsonPayload.terminalState="FAILED"
  EOT

  metric_descriptor {
    metric_kind  = "DELTA"
    value_type   = "INT64"
    unit         = "1"
    display_name = "Dataform Workflow Failures"
  }

  depends_on = [google_project_service.logging_api]
}

################################################################################
# Notification Channel (Email)
################################################################################

resource "google_monitoring_notification_channel" "dataform_email" {
  project      = var.gcp_project_id
  display_name = "Dataform Alerts Email"
  type         = "email"

  labels = {
    email_address = var.alert_recipient_email
  }

  depends_on = [google_project_service.monitoring_api]
}

################################################################################
# Alert Policy (Dataform workflow failures)
################################################################################

resource "google_monitoring_alert_policy" "dataform_failure_alert" {
  project      = var.gcp_project_id
  display_name = "Dataform Workflow Failure Alert"
  combiner     = "OR"

  conditions {
    display_name = "Dataform workflow failed"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/dataform-workflow-failures\" AND resource.type=\"dataform.googleapis.com/Repository\""
      duration        = "0s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.dataform_email.id]

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
    auto_close = "604800s"
  }

  documentation {
    content   = <<-EOT
      Dataform ワークフロー実行が失敗しました。

      ## 確認事項
      1. Cloud Logging で詳細なエラーログを確認
      2. Dataform コンソールでワークフロー実行履歴を確認
      3. SQL エラーやリソース不足などの原因を特定

      ## 対応方法
      - SQL の修正が必要な場合: dataform/ ディレクトリ内の該当ファイルを修正
      - データソースの問題: BigQuery DTS の状態を確認
      - リソース不足: BigQuery のクォータを確認

      ## 関連リンク
      - Dataform コンソール: https://console.cloud.google.com/bigquery/dataform
      - Cloud Logging: https://console.cloud.google.com/logs/query
    EOT
    mime_type = "text/markdown"
  }

  depends_on = [
    google_logging_metric.dataform_failures,
    google_monitoring_notification_channel.dataform_email
  ]
}

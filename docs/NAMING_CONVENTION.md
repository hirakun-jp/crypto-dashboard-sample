# 命名規則

本ドキュメントは、本リポジトリにおけるTerraform、GCPリソース、Dataformの厳密な命名規則を定義する。

---

# Part 1: Terraform 命名規則

Terraformコード内での識別子の命名規則。

## 1.1 変数（Variables）

| 項目 | ルール |
|------|--------|
| 形式 | `snake_case`（小文字 + アンダースコア） |
| プレフィックス | サービス/スコープを示す（例: `gcp_`, `github_`, `alert_`） |
| 禁止 | ハイフン、大文字、略語の乱用 |

```hcl
# Good
variable "gcp_project_id" {}
variable "alert_recipient_email" {}

# Bad
variable "projectId" {}      # camelCase禁止
variable "proj_id" {}        # 略語禁止
```

## 1.2 ローカル変数（Locals）

| 項目 | ルール |
|------|--------|
| 形式 | `snake_case` |
| 用途 | 環境サフィックス、共通プレフィックスの集約 |

```hcl
locals {
  env_suffix_underscore = var.environment == "prod" ? "" : "_${var.environment}"
  env_suffix_hyphen     = var.environment == "prod" ? "" : "-${var.environment}"
}
```

## 1.3 リソースローカル名（Resource Local Names）

| 項目 | ルール |
|------|--------|
| 形式 | `snake_case` |
| 原則 | **GCPリソース名と一致させる**（ハイフン→アンダースコア変換） |

```hcl
# Good: ローカル名とaccount_idが対応
resource "google_service_account" "hyperliquid_ingest_function_sa" {
  account_id = "hyperliquid-ingest-function-sa"
}

resource "google_service_account" "hyperliquid_dataform_sa" {
  account_id = "hyperliquid-dataform-sa"
}

# Bad: ローカル名とaccount_idが乖離
resource "google_service_account" "cloudbuild" {
  account_id = "cloudbuild-functions-sa"
}
```

## 1.4 IAMリソースローカル名

| 項目 | ルール |
|------|--------|
| 形式 | `snake_case` |
| 構造 | `{sa_name}_{target}_{role_suffix}` |

```hcl
# Project IAM（SA名 + 対象リソース + ロール）
google_project_iam_member.hyperliquid_dataform_sa_bigquery_job_user
google_project_iam_member.functions_cloudbuild_sa_artifact_registry_writer

# Dataset IAM
google_bigquery_dataset_iam_member.hyperliquid_dataform_sa_sources_viewer

# Service Account IAM
google_service_account_iam_member.hyperliquid_dataform_sa_token_creator
```

## 1.5 ラベル（Labels）

| ラベルキー | 必須/任意 | 値のルール |
|-----------|----------|-----------|
| `environment` | 必須 | `prod`, `dev` |
| `layer` | 必須（BigQuery） | `sources`, `staging`, `intermediate`, `marts` |
| `managed_by` | 必須 | `terraform` |

## 1.6 禁止事項

1. **略語の乱用**: `proj`, `env`, `sa` → `project`, `environment`, `service_account`
2. **汎用的すぎる名前**: `main`, `default`, `primary`
3. **バージョン番号の埋め込み**: `v1`, `_v2`（タグで管理）
4. **個人名・チーム名の埋め込み**

## 1.7 例外事項

| 対象 | 許容される例外 | 理由 |
|-----|--------------|------|
| Google管理SA | `service-{number}@gcp-sa-*.iam.gserviceaccount.com` | GCPが自動生成 |
| 既存リソース | 現行命名を維持 | 破壊的変更回避 |
| SA account_id 30文字超過 | ドメイン名を略称化（例: `hyperliquid` → `hl`） | GCP制限（6-30文字） |

---

# Part 2: GCPリソース命名規則

GCPに作成される実際のリソース名の命名規則。

## 2.0 命名思想

**サフィックス型**を採用する。リソース種別は末尾に配置し、ドメインでグループ化する。

### 基本構造

| 要素 | 必須/任意 | 説明 | 例 |
|------|----------|------|-----|
| domain | 必須 | データソース/ビジネスドメイン | `hyperliquid`, `salesforce`, `ga4` |
| purpose | 必須 | 処理の目的 | `ingest`, `export`, `transform`, `sync` |
| frequency | 条件付き | 実行頻度（Scheduler/DTS必須） | `daily`, `hourly`, `monthly` |
| write_mode | 条件付き | 書き込みモード（DTS転送名のみ必須） | `truncate`, `append` |
| resource | 必須 | GCPリソース種別（**フルネーム**） | `function`, `scheduler`, `transfer`, `dataform` |
| env | 任意 | 環境（prod以外） | `dev` |

### リソースタイプ別の構造

| リソースタイプ | 構造 | 例 |
|---------------|------|-----|
| サービスアカウント | `{domain}-{purpose}[-{frequency}]-{resource}-sa[-{env}]` | `hyperliquid-ingest-function-sa-dev` |
| Cloud Functions | `{domain}-{purpose}-function[-{env}]` | `hyperliquid-ingest-function-dev` |
| Cloud Scheduler | `{domain}-{purpose}-{frequency}-scheduler[-{env}]` | `hyperliquid-ingest-daily-scheduler-dev` |
| DTS転送設定 | `{domain}-{purpose}-{frequency}-{write_mode}-transfer[-{env}]` | `hyperliquid-load-daily-truncate-transfer-dev` |
| DTS用SA | `{domain}-{purpose}-{frequency}-transfer-sa[-{env}]` | `hyperliquid-load-daily-transfer-sa-dev` |

**設計理由**:
- IAM一覧でドメイン単位にグループ化され、関連リソースが隣接する
- `hyperliquid-*` で検索すると、HyperLiquid関連のリソースが全て抽出できる
- 略語（cf, sched等）を禁止し、可読性を優先
- 環境サフィックスは常に末尾で統一
- `-sa` サフィックスでサービスアカウントであることを明示

## 2.1 サービスアカウント（Service Account）

| 項目 | ルール |
|------|--------|
| 形式 | `kebab-case`（小文字 + ハイフン） |
| 構造 | `{domain}-{purpose}[-{frequency}]-{resource}-sa[-{env}]` |
| 最大長 | 30文字 |
| 必須サフィックス | `-sa`（サービスアカウントであることを明示） |

| リソース種別 | サフィックス | 例 |
|-------------|-------------|-----|
| Cloud Functions | `-function-sa` | `hyperliquid-ingest-function-sa` |
| Cloud Scheduler | `-scheduler-sa` | `hyperliquid-ingest-daily-scheduler-sa` |
| BigQuery DTS | `-transfer-sa` | `hyperliquid-load-monthly-transfer-sa` |
| Dataform | `-dataform-sa` | `analytics-dataform-sa`（ドメイン非依存） |
| Looker Studio | `-looker-studio-sa` | `analytics-looker-studio-sa`（ドメイン非依存） |
| Cloud Build | `-cloudbuild-sa` | `functions-cloudbuild-sa`（汎用） |

**IAM一覧での表示例**（アルファベット順）:
```
analytics-dataform-sa
analytics-looker-studio-sa
functions-cloudbuild-sa
hyperliquid-ingest-daily-scheduler-sa
hyperliquid-ingest-function-sa
hyperliquid-ingest-function-sa-dev
hyperliquid-load-daily-transfer-sa
hyperliquid-load-daily-transfer-sa-dev
```

**注**: Dataform と Looker Studio のSAは複数ドメインで共有するため、`analytics-` プレフィックスを使用

## 2.2 BigQueryデータセット

| 項目 | ルール |
|------|--------|
| 形式 | `snake_case` |
| 構造 | `{layer}_{domain}[_{environment}]` |
| 環境サフィックス | prod: なし、dev: `_dev` |

| レイヤ | プレフィックス | 例 |
|--------|---------------|-----|
| Sources | `src_` | `src_hyperliquid` |
| Staging | `stg_` | `stg_hyperliquid`, `stg_hyperliquid_dev` |
| Intermediate | `int_` | `int_coin_trend`, `int_coin_trend_dev` |
| Marts | `mart_` | `mart_coin_trend`, `mart_shared` |

## 2.3 BigQueryテーブル

| 項目 | ルール |
|------|--------|
| 形式 | `snake_case` |
| 構造 | レイヤごとに異なる（下表参照） |

### レイヤ別命名規則

| レイヤ | 構造 | 例 |
|--------|------|-----|
| Sources | `{entity}` | `candles`, `orders`, `users` |
| Staging | `{entity}` | `candles`, `orders` |
| Intermediate | `{entity}_{verb}` | `candles_deduplicated`, `candles_enriched` |
| Marts (Fact) | `fact_{entity}[_{frequency}]` | `fact_candles`, `fact_candles_hourly`, `fact_trades_monthly` |
| Marts (Dimension) | `dim_{entity}` | `dim_dates`, `dim_symbols` |
| Marts (Wide) | `wide_{entity}[_{frequency}]` | `wide_candles`, `wide_candles_monthly` |

**注**:
- `{entity}` は複数形を使用（`candle` → `candles`）
- staging / intermediate のテーブル名にはプレフィックス不要（データセット名で区別）
- Intermediate の `{verb}` は処理内容を示す（`deduplicated`, `enriched`, `joined`）
- Wide テーブルはレポート用の One Big Table（OBT）
- Marts の `_{frequency}` サフィックス（`_hourly`, `_daily`, `_monthly`）は集計粒度が異なるテーブルを区別する場合に使用

## 2.4 Cloud Functions

| 項目 | ルール |
|------|--------|
| 形式 | `kebab-case` |
| 構造 | `{domain}-{purpose}-function[-{env}]` |
| 環境サフィックス | prod: なし、dev: `-dev` |

```
hyperliquid-ingest-function           # prod
hyperliquid-ingest-function-dev       # dev
hyperliquid-transform-function        # prod
```

## 2.5 Cloud Scheduler

| 項目 | ルール |
|------|--------|
| 形式 | `kebab-case` |
| 構造 | `{domain}-{purpose}-{frequency}-scheduler[-{env}]` |

```
hyperliquid-ingest-daily-scheduler
hyperliquid-ingest-hourly-scheduler
hyperliquid-load-monthly-scheduler
hyperliquid-load-monthly-scheduler-dev
```

## 2.6 Storage Bucket

| 項目 | ルール |
|------|--------|
| 形式 | `kebab-case` |
| 構造 | `{project_id}-{purpose}` |
| グローバル一意性 | project_idで担保 |

```
my-project-123-functions-source
```

## 2.7 Secret Manager

| 項目 | ルール |
|------|--------|
| 形式 | `kebab-case` |
| 構造 | `{service}-{purpose}[-{env}]` |

```
dataform-github-token
dataform-github-token-dev
```

## 2.8 BigQuery Data Transfer Service（DTS）

| 項目 | ルール |
|------|--------|
| 形式 | `kebab-case` |
| 構造（転送名） | `{domain}-{purpose}-{frequency}-{write_mode}-transfer[-{env}]` |
| 構造（SA） | `{domain}-{purpose}-{frequency}-transfer-sa[-{env}]` |
| 環境サフィックス | prod: なし、dev: `-dev` |

### 要素の説明

| 要素 | 必須/任意 | 値 | 説明 |
|------|----------|-----|------|
| domain | 必須 | `hyperliquid`, `ga4` など | データソース |
| purpose | 必須 | `load`, `sync` | 処理目的（BigQueryへの取り込み） |
| frequency | 必須 | `daily`, `hourly`, `monthly` | 実行頻度 |
| write_mode | 必須 | `truncate`, `append` | 書き込みモード |
| env | 任意 | `dev` | 環境（prod以外） |

**注**: `export` は BigQuery からの出力を意味するため、BigQuery への取り込みには `load` を使用

### 書き込みモード

| モード | 説明 | ユースケース |
|--------|------|-------------|
| `truncate` | 毎回全件洗い替え | 最新断面の分析 |
| `append` | 差分追記 | 履歴分析 |

### 転送設定の display_name 例

```
# prod環境
hyperliquid-load-daily-truncate-transfer      # 日次洗い替え（最新断面）
hyperliquid-load-daily-append-transfer        # 日次追記（履歴分析）
ga4-load-daily-append-transfer                # GA4イベント追記
salesforce-sync-hourly-truncate-transfer      # 時間単位マスタ同期

# dev環境
hyperliquid-load-daily-truncate-transfer-dev
hyperliquid-load-daily-append-transfer-dev
```

### サービスアカウント例

```
# prod環境（write_modeはSA名に含めない）
hyperliquid-load-daily-transfer-sa
hyperliquid-load-monthly-transfer-sa
ga4-load-daily-transfer-sa

# dev環境
hyperliquid-load-daily-transfer-sa-dev
hyperliquid-load-monthly-transfer-sa-dev
```

**注**: 同一ドメイン・頻度で複数の書き込みモードがある場合も、SAは共有可能

### Terraformリソース例（S3 → BigQuery）

```hcl
# 転送設定（S3からの取り込み）
resource "google_bigquery_data_transfer_config" "hyperliquid_load_daily_truncate_transfer" {
  for_each = toset(var.environments)

  display_name           = each.value == "prod" ? "hyperliquid-load-daily-truncate-transfer" : "hyperliquid-load-daily-truncate-transfer-${each.value}"
  location               = var.gcp_region
  data_source_id         = "amazon_s3"
  schedule               = var.dts_schedule
  destination_dataset_id = google_bigquery_dataset.sources[each.value].dataset_id
  project                = var.gcp_project_id

  params = {
    data_path_template              = "s3://hyperliquid-archive/asset_ctxs/{date}.csv.lz4"
    destination_table_name_template = "asset_ctxs_{date_str}"
    file_format                     = "Parquet"
    write_disposition               = "WRITE_TRUNCATE"
    access_key_id                   = var.aws_access_key_id
    secret_access_key               = var.aws_secret_access_key
    role_arn                        = var.aws_dts_role_arn
  }

  service_account_name = google_service_account.hyperliquid_load_daily_transfer_sa.email

  email_preferences {
    enable_failure_email = true
  }

  disabled = each.value == "dev" ? true : false
}

# サービスアカウント
resource "google_service_account" "hyperliquid_load_daily_transfer_sa" {
  account_id   = "hyperliquid-load-daily-transfer-sa"
  display_name = "DTS - HyperLiquid Daily Load"
}
```

## 2.9 Dataformリポジトリ / ワークスペース

| 項目 | ルール |
|------|--------|
| 形式 | `kebab-case` |
| リポジトリ構造 | `{project}-dataform` |
| ワークスペース構造 | `{branch-name}` または `{developer-name}` |

### リポジトリ名

```
analytics-dataform          # 分析用（複数ドメインを包含）
```

**注**: Dataformリポジトリは複数ドメインのデータを扱うため、ドメイン非依存の命名を使用

### ワークスペース名

```
# ブランチベース（推奨）
main                        # 本番用
develop                     # 開発統合用
feature-coin-trend          # 機能開発用

# 開発者ベース（個人開発時）
tanaka
suzuki
```

## 2.10 Monitoring

| 項目 | ルール |
|------|--------|
| メトリクス | `kebab-case`: `{service}-{event}` |
| 通知チャネル | `kebab-case`: `{service}-{type}` |
| アラートポリシー | Display Name: `{Service} {Event} Alert` |

```
dataform-workflow-failures       # メトリクス
dataform-email                   # 通知チャネル
Dataform Workflow Failure Alert  # アラートポリシー表示名
```

## 2.11 環境サフィックス規則

| リソースタイプ | 区切り文字 | prod | dev |
|---------------|-----------|------|-----|
| BigQueryデータセット | アンダースコア `_` | `stg_hyperliquid` | `stg_hyperliquid_dev` |
| Cloud Functions | ハイフン `-` | `hyperliquid-ingest-function` | `hyperliquid-ingest-function-dev` |
| Cloud Scheduler | ハイフン `-` | `hyperliquid-ingest-daily-scheduler` | `hyperliquid-ingest-daily-scheduler-dev` |
| サービスアカウント | ハイフン `-` | `hyperliquid-ingest-function-sa` | `hyperliquid-ingest-function-sa-dev` |
| DTS転送設定 | ハイフン `-` | `hyperliquid-load-daily-truncate-transfer` | `hyperliquid-load-daily-truncate-transfer-dev` |
| Secret Manager | ハイフン `-` | `dataform-github-token` | `dataform-github-token-dev` |

**ルール**:
- prod環境: サフィックスなし
- dev環境: `-dev` または `_dev`（リソースタイプに応じて）
- 環境サフィックスは常に**末尾**に配置

---

# Part 3: Dataform 命名規則

Dataform（SQLワークフロー）の命名規則。

## 3.1 ディレクトリ構造

```
definitions/
├── sources/           # ソース宣言（.sqlx）
├── staging/           # ステージングビュー/テーブル
│   └── hyperliquid/   # ソース別サブディレクトリ
├── intermediate/      # 中間テーブル
│   └── coin_trend/    # ドメイン別サブディレクトリ
└── marts/             # BIマート（fact_, dim_）
    ├── coin_trend/    # ドメイン別
    └── shared/        # 共有ディメンション
```

## 3.2 ファイル名

| 項目 | ルール |
|------|--------|
| 形式 | `snake_case.sqlx` |
| 原則 | 出力テーブル名と一致させる |

```
# Good
candles.sqlx                     → candles テーブル（staging / intermediate）
candles_deduplicated.sqlx        → candles_deduplicated テーブル（intermediate）
fact_candles.sqlx                → fact_candles テーブル（marts）
dim_calendar.sqlx                → dim_calendar テーブル（marts）
wide_candles.sqlx                → wide_candles テーブル（marts）

# Bad
candleData.sqlx       # camelCase禁止
candle-1h.sqlx        # ハイフン禁止
```

## 3.3 テーブル/ビュー名

| レイヤ | 構造 | 例 |
|--------|------|-----|
| Sources | `{entity}` | `candles` |
| Staging | `{entity}` | `candles` |
| Intermediate | `{entity}_{verb}` | `candles_deduplicated` |
| Marts (Fact) | `fact_{entity}[_{frequency}]` | `fact_candles`, `fact_candles_hourly` |
| Marts (Dimension) | `dim_{entity}` | `dim_calendar` |
| Marts (Wide) | `wide_{entity}[_{frequency}]` | `wide_candles`, `wide_candles_monthly` |

**注**:
- `{entity}` は複数形を使用
- staging / intermediate のテーブル名にはプレフィックス不要（データセット名で区別）
- `{verb}` は処理内容を示す動詞（過去分詞）
- Wide テーブルはレポート用の One Big Table（OBT）
- `_{frequency}` サフィックス（`_hourly`, `_daily`, `_monthly`）は集計粒度が異なるテーブルを区別する場合に使用

## 3.4 スキーマ名（config.schema）

| レイヤ | スキーマ名 | 環境対応 |
|--------|-----------|---------|
| Sources | `src_{domain}` | prod固定 |
| Staging | `stg_{domain}` | `dataform.projectConfig.vars.env_suffix` で切り替え |
| Intermediate | `int_{domain}` | 同上 |
| Marts | `mart_{domain}` | 同上 |

```sqlx
config {
  schema: "stg_hyperliquid" + dataform.projectConfig.vars.env_suffix
}
```

## 3.5 タグ（config.tags）

| カテゴリ | タグ | 用途 |
|---------|------|------|
| レイヤ | `sources`, `staging`, `intermediate`, `marts` | レイヤ識別 |
| テーブル種別 | `fact`, `dimension`, `wide` | marts内の種別 |
| 実行頻度 | `daily`, `hourly`, `monthly` | スケジュール実行の選択 |

### レイヤ別必須タグ

| レイヤ | 必須タグ |
|--------|---------|
| Sources | `["sources"]` |
| Staging | `["staging", "{frequency}"]` |
| Intermediate | `["intermediate", "{frequency}"]` |
| Marts (Fact) | `["marts", "fact", "{frequency}"]` |
| Marts (Dimension) | `["marts", "dimension", "{frequency}"]` |
| Marts (Wide) | `["marts", "wide", "{frequency}"]` |

### 例

```sqlx
config {
  type: "table",
  schema: "mart_coin_trend",
  tags: ["marts", "fact", "daily"]
}
```

## 3.6 参照（ref）の書き方

```sqlx
-- スキーマを明示する（推奨）
${ref("stg_hyperliquid", "candles")}

-- 同一スキーマ内は省略可
${ref("candles")}
```

## 3.7 CTEの命名

| 項目 | ルール |
|------|--------|
| 形式 | `snake_case` |
| 命名パターン | `{entity}_{verb}` または `final` |

```sql
WITH
  candles_deduplicated AS (...),
  candles_with_indicators AS (...),
  final AS (...)

SELECT * FROM final
```

## 3.8 カラム命名

| 項目 | ルール |
|------|--------|
| 形式 | `snake_case` |
| サフィックス | 型/意味に応じて付与（下表参照） |
| ブール型 | `is_`, `has_`, `can_` プレフィックス必須 |

### サフィックス一覧（型情報付き）

| サフィックス | 用途 | BigQuery型 | 例 |
|-------------|------|-----------|-----|
| `_id` | 識別子（主キー、外部キー） | `STRING` | `user_id`, `order_id` |
| `_key` | サロゲートキー | `INT64` | `date_key`, `customer_key` |
| `_at` | タイムスタンプ（日時、UTC） | `TIMESTAMP` | `created_at`, `updated_at` |
| `_at_jst` | タイムスタンプ（日時、JST） | `TIMESTAMP` | `created_at_jst`, `updated_at_jst` |
| `_date` | 日付（時刻なし） | `DATE` | `incurred_month_start_date`, `order_date` |
| `_time` | 時刻（日付なし） | `TIME` | `open_time`, `close_time` |
| `_name` | 名称 | `STRING` | `symbol_name`, `customer_name` |
| `_code` | コード値 | `STRING` | `currency_code`, `status_code` |
| `_type` | 種別 | `STRING` | `order_type`, `account_type` |
| `_status` | 状態 | `STRING` | `order_status`, `payment_status` |
| `_count` | 件数 | `INT64` | `trade_count`, `order_count` |
| `_amount` | 金額 | `NUMERIC` | `total_amount`, `fee_amount` |
| `_price` | 価格 | `NUMERIC` | `open_price`, `close_price` |
| `_qty` / `_quantity` | 数量 | `NUMERIC` | `order_qty`, `filled_quantity` |
| `_volume` | 出来高 | `NUMERIC` | `trade_volume`, `daily_volume` |
| `_pct` / `_percent` | 割合（0-100） | `FLOAT64` | `change_pct`, `fee_percent` |
| `_ratio` | 比率（0-1） | `FLOAT64` | `win_ratio`, `fill_ratio` |
| `_yoy` | 前年比（1以上あり） | `FLOAT64` | `revenue_yoy`, `order_count_yoy` |
| `_url` | URL | `STRING` | `image_url`, `callback_url` |
| `_path` | ファイルパス | `STRING` | `file_path`, `config_path` |
| `_json` | JSON文字列 | `JSON` / `STRING` | `metadata_json`, `config_json` |
| `_flag` | （使用禁止） | - | `is_xxx` を使う |

**注**:
- `_at` は基本的に UTC タイムスタンプを格納
- JST で格納する場合は `_at_jst` サフィックスを使用

### ブール型プレフィックス

| プレフィックス | BigQuery型 | 用途 | 例 |
|---------------|-----------|------|-----|
| `is_` | `BOOL` | 状態を表す | `is_active`, `is_deleted` |
| `has_` | `BOOL` | 所有を表す | `has_children`, `has_discount` |
| `can_` | `BOOL` | 可否を表す | `can_cancel`, `can_edit` |

### カラム名の例（本プロジェクト）

```sql
-- 価格関連（NUMERIC型）
open                    -- Bad: サフィックスなし、型不明
open_price              -- Good: NUMERIC型であることが明確

-- 金額関連（NUMERIC型）
total                   -- Bad: 何のtotalか不明
total_amount            -- Good: 金額であることが明確

-- タイムスタンプ（TIMESTAMP型）
updated                 -- Bad: 型が不明
updated_at              -- Good: TIMESTAMP型であることが明確

-- 計算値（FLOAT64型）
price_change            -- OK: 差分値（NUMERICでも可）
price_change_pct        -- Good: FLOAT64の割合であることが明確

-- ブール型（BOOL型）
active                  -- Bad: ブール型が不明
is_active               -- Good: BOOL型であることが明確

-- ID/キー
date                    -- Bad: 役割が不明
date_key                -- Good: INT64のサロゲートキーであることが明確
```

### 禁止パターン

```sql
-- camelCase
updatedAt               -- Bad: snake_case必須
priceChangePCT          -- Bad: 大文字禁止

-- 略語の乱用
qty                     -- Bad: quantity を使う（ただし _qty サフィックスはOK）
amt                     -- Bad: amount を使う
num                     -- Bad: number または count を使う
ts                      -- Bad: timestamp または _at を使う

-- 曖昧な名前
value                   -- Bad: 何の値か不明
data                    -- Bad: 何のデータか不明
flag                    -- Bad: is_xxx を使う
temp                    -- Bad: 用途を明示する
```

---

# 付録: 現状コードとの差分

現状で本規則に沿っていない箇所（参考情報。修正は破壊的変更となるため非推奨）：

## サービスアカウント

| 現状 account_id | 規則準拠案 |
|----------------|-----------|
| `cloudbuild-functions` | `functions-cloudbuild-sa` |
| `cf-ingest-hyperliquid` | `hyperliquid-ingest-function-sa` |
| `scheduler-ingest-hyperliquid` | `hyperliquid-ingest-daily-scheduler-sa` |
| `dataform-hyperliquid` | `analytics-dataform-sa` |
| `looker-studio-viewer` | `analytics-looker-studio-sa` |

## Terraformローカル名

| ファイル | 現状 | 規則準拠案 |
|---------|------|-----------|
| iam.tf:9 | `google_service_account.cloudbuild` | `google_service_account.functions_cloudbuild_sa` |
| iam.tf:69 | `google_service_account.cloud_functions` | `google_service_account.hyperliquid_ingest_function_sa` |
| iam.tf:93 | `google_service_account.cloud_scheduler` | `google_service_account.hyperliquid_ingest_daily_scheduler_sa` |
| iam.tf:124 | `google_service_account.dataform` | `google_service_account.analytics_dataform_sa` |
| iam.tf:214 | `google_service_account.looker_studio` | `google_service_account.analytics_looker_studio_sa` |

## Cloud Functions / Scheduler

| リソース | 現状 | 規則準拠案 |
|---------|------|-----------|
| Cloud Function | `ingest-hyperliquid` | `hyperliquid-ingest-function` |
| Cloud Scheduler | `ingest-hyperliquid-daily` | `hyperliquid-ingest-daily-scheduler` |

## Dataformリポジトリ

| 現状 | 規則準拠案 |
|------|-----------|
| `hyperliquid-dataform` | `analytics-dataform` |

## BigQueryテーブル（Dataform）

| 現状 | 規則準拠案 |
|------|-----------|
| `candle_1h` (staging) | `candles` |
| `candle_1h` (intermediate) | `candles_with_indicators` |
| `fact_candle_1h` (marts) | `fact_candles` |

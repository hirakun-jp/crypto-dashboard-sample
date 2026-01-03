<div align="center">

# Crypto Market Data Pipeline

![BigQuery](https://img.shields.io/badge/BigQuery-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Dataform](https://img.shields.io/badge/Dataform-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)

暗号資産マーケットデータの可視化パイプライン（学習・検証用途）

</div>

## クイックスタート

### 1. 認証

**Bash / macOS / Linux:**
```bash
export PROJECT_ID="your-gcp-project-id"
gcloud auth login
gcloud config set project ${PROJECT_ID}
gcloud auth application-default login
gcloud auth application-default set-quota-project ${PROJECT_ID}
```

**PowerShell (Windows):**
```powershell
$env:PROJECT_ID = "your-gcp-project-id"
gcloud auth login
gcloud config set project $env:PROJECT_ID
gcloud auth application-default login
gcloud auth application-default set-quota-project $env:PROJECT_ID
```

### 2. Terraform 実行

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集

terraform init && terraform apply
```

## ディレクトリ構成

```
.
├── terraform/              # インフラ定義
│   ├── main.tf             # Provider設定 + API有効化
│   ├── variables.tf        # 変数定義
│   ├── bigquery.tf         # データセット定義
│   ├── functions.tf        # Cloud Run Functions + Cloud Scheduler
│   ├── iam.tf              # Service Account + IAM
│   ├── dataform.tf         # Dataform Repository + Release/Workflow Config
│   ├── monitoring.tf       # Cloud Monitoring（アラート）
│   └── secrets.tf          # Secret Manager
├── functions/
│   └── ingest_hyperliquid/ # HyperLiquid API → BigQuery
│       ├── main.py         # Cloud Functions エントリポイント
│       └── requirements.txt
├── definitions/            # Dataform SQLワークフロー（ルート直下）
│   ├── sources/            # API取り込みデータ宣言
│   ├── staging/            # 列名調整・重複除去
│   ├── intermediate/       # ビジネスロジック
│   └── marts/              # BI用集計（fact_, dim_）
├── workflow_settings.yaml  # Dataform Native設定
├── DEPLOYMENT.md           # デプロイ手順
└── README.md               # 本ファイル
```

## データモデル

| レイヤ | データセット | 責務 |
|:---:|:---|:---|
| Sources | `src_hyperliquid` | Cloud Functions書き込み専用（candle_1h） |
| Staging | `stg_hyperliquid` | 重複除去・列名調整 |
| Intermediate | `int_coin_trend` | 技術指標（price_change_pct等）算出 |
| Marts | `mart_coin_trend` | fact_candle_1h（BI用集計） |
| Marts | `mart_shared` | dim_calendar（共有ディメンション） |

## 実行スケジュール

| 時刻 (JST) | 処理 |
|:---:|:---|
| 02:00 | Cloud Functions: HyperLiquid API → src_hyperliquid |
| 03:00 | Dataform Workflow: stg → int → mart 変換 |

## IAM

### サービスアカウント

| アカウントID | 用途 | 権限 |
|:---|:---|:---|
| `cloudbuild-functions` | Cloud Build（Functions Gen2ビルド） | cloudbuild.builds.builder, artifactregistry.writer, run.admin, iam.serviceAccountUser, logging.logWriter, storage.objectViewer |
| `cf-ingest-hyperliquid` | Cloud Functions（API→BigQuery） | bigquery.jobUser, src: dataEditor |
| `scheduler-ingest-hyperliquid` | Cloud Scheduler（Functions呼び出し） | cloudfunctions.invoker, run.invoker |
| `dataform-hyperliquid` | Dataform SQLワークフロー | bigquery.jobUser, bigquery.user, src: dataViewer, stg/int/mart: dataEditor |
| `looker-studio-viewer` | Looker Studio BI参照 | bigquery.jobUser, mart: dataViewer, Looker Studio SA: tokenCreator |

### ユーザーIAM（本番運用時の参考）

| ロール | sources | staging | intermediate | marts | Dataform | Looker Studio SA |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| データエンジニア | Editor | Editor | Editor | Editor | Admin | - |
| 社内アナリスト | Viewer | Viewer | Editor | Editor | Editor | - |
| 業務委託アナリスト | - | Viewer | Editor | Editor | Editor | - |
| ビジネスユーザー | - | - | - | Viewer | - | serviceAccountUser |

> 本リポジトリはサンプル実装のため、ユーザーIAMはTerraformに含めていない。
> `terraform/iam.tf` にテンプレートをコメントアウトで記載。
> ビジネスユーザーがLooker Studioでデータソースを作成する場合、`looker-studio-viewer` SAへの `serviceAccountUser` 権限が必要。

## 過去データの取得（バックフィル）

デプロイ後、過去データを取得してダッシュボードを確認したい場合：

**Bash / macOS / Linux:**
```bash
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  "https://asia-northeast1-<PROJECT_ID>.cloudfunctions.net/ingest-hyperliquid?start_date=2025-10-01&end_date=2025-12-31"
```

**PowerShell (Windows):**
```powershell
curl.exe -H "Authorization: Bearer $(gcloud auth print-identity-token)" `
  "https://asia-northeast1-<PROJECT_ID>.cloudfunctions.net/ingest-hyperliquid?start_date=2025-10-01&end_date=2025-12-31"
```

## 注意事項

- `terraform.tfvars` はGitにコミットしない
- 失敗時は Cloud Monitoring からメール通知

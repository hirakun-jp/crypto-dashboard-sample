<div align="center">

# Crypto Market Data Pipeline

### HyperLiquid API → BigQuery → Dataform → Looker Studio

![BigQuery](https://img.shields.io/badge/BigQuery-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Dataform](https://img.shields.io/badge/Dataform-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)

暗号資産マーケットデータの可視化パイプライン（学習・検証用途）

</div>

---

## クイックスタート

### 1. 認証

```bash
export PROJECT_ID="your-gcp-project-id"
gcloud auth login
gcloud config set project ${PROJECT_ID}
gcloud auth application-default login
gcloud auth application-default set-quota-project ${PROJECT_ID}
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
├── .claude/                 # Claude Code 設定
├── terraform/               # BigQuery, Cloud Functions, Dataform, Monitoring
├── functions/
│   └── ingest_hyperliquid/  # HyperLiquid API → BigQuery
└── dataform/
    └── definitions/         # sources/ staging/ intermediate/ marts/
```

## データモデル

| レイヤ | データセット | 責務 |
|:---:|:---|:---|
| Sources | `src_hyperliquid` | Cloud Functions書き込み専用 |
| Staging | `stg_hyperliquid` | 列名調整・型変換 |
| Intermediate | `int_coin_trend` | ビジネスロジック |
| Marts | `mart_coin_trend`, `mart_shared` | BI用集計 |

## 実行スケジュール

| 時刻 | 処理 |
|:---:|:---|
| 02:00 | Cloud Functions（HyperLiquid API → src） |
| 03:00 | Dataform（stg → int → mart） |

## IAM

### サービスアカウント

| アカウントID | 用途 | 権限 |
|:---|:---|:---|
| `cf-ingest-hyperliquid` | Cloud Functions（API→BigQuery） | src: Editor |
| `scheduler-ingest-hyperliquid` | Cloud Scheduler（Functions呼び出し） | cloudfunctions.invoker, run.invoker |
| `dataform-hyperliquid` | Dataform SQLワークフロー | src: Viewer / stg,int,mart: Editor |
| `looker-studio-viewer` | Looker Studio BI参照 | mart: Viewer のみ |

### 人間用IAM（本番運用時の参考）

| ロール | sources | staging | intermediate | marts | Dataform |
|:---|:---:|:---:|:---:|:---:|:---:|
| データエンジニア | Editor | Editor | Editor | Editor | Admin |
| 社内アナリスト | Viewer | Viewer | Editor | Editor | Editor |
| 業務委託アナリスト | - | Viewer | Editor | Editor | Editor |
| ビジネスユーザー | - | - | - | Viewer | - |

> 本リポジトリはサンプル実装のため、人間用IAMはTerraformに含めていない。
> `terraform/iam.tf` にテンプレートをコメントアウトで記載。

## 注意事項

- `terraform.tfvars` はGitにコミットしない
- 失敗時は Cloud Monitoring からメール通知

---

<div align="center">

*Powered by Claude Code*

</div>

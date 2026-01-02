# デプロイ手順

## 前提条件

- Google Cloud CLI (gcloud) インストール済み
- Terraform インストール済み
- GCPプロジェクト（課金有効）
- GitHub Personal Access Token（repo権限）
- Git / GitHub リポジトリ設定済み

## Step 1: GCP認証

```bash
gcloud auth login
gcloud auth application-default login
```

## Step 2: terraform.tfvars 作成

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` を編集：

```hcl
gcp_project_id        = "あなたのプロジェクトID"
gcp_region            = "asia-northeast1"
environments          = ["dev", "prod"]
alert_recipient_email = "あなたのメールアドレス"
github_repository_url = "https://github.com/あなたのorg/このリポジトリ.git"
github_token          = "ghp_xxxxxxxxxxxxxxxx"
```

## Step 3: GitHub Personal Access Token 作成

1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. 権限: `repo` (Full control)
4. 生成されたトークンを `terraform.tfvars` の `github_token` に設定

## Step 4: Terraform実行

```bash
cd terraform
terraform init
terraform plan
```

問題なければ：

```bash
terraform apply
```

## Step 5: 動作確認

### GCPコンソールで確認

| リソース | 確認場所 | 確認内容 |
|---------|---------|---------|
| Cloud Functions | Cloud Run Functions | `ingest-hyperliquid` が作成されている |
| BigQuery | BigQuery | データセット（`src_hyperliquid`, `stg_hyperliquid_dev` 等）が作成されている |
| Dataform | Dataform | `hyperliquid-dataform` リポジトリが作成されている |
| Cloud Scheduler | Cloud Scheduler | `trigger-ingest-hyperliquid` が作成されている |

## Step 6: 手動テスト

### Cloud Functions（データ取り込み）

```bash
gcloud functions call ingest-hyperliquid --region=asia-northeast1
```

### Dataform（SQLワークフロー）

1. GCPコンソール → Dataform → `hyperliquid-dataform`
2. Workspaces → 新規作成 or 既存選択
3. Start Execution → Execute all

## 補足: Dataformの仕組み

```
GitHub リポジトリ (main ブランチ)
        ↓ 参照
Dataform Repository (GCP内)
        ↓ コンパイル
Release Config (prod)
        ↓ 毎日03:00実行
Workflow Config → BigQuery テーブル更新
```

Terraformが `git_remote_settings` でGitHubリポジトリを参照するため、Dataform専用リポジトリの作成は不要。

## スケジュール

| ジョブ | 実行時刻 (JST) | 内容 |
|-------|---------------|------|
| Cloud Scheduler | 毎日 02:00 | HyperLiquid API → BigQuery (src) |
| Dataform Workflow | 毎日 03:00 | stg → int → mart 変換 |

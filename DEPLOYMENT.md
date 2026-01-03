# デプロイ手順

## 前提条件

- Google Cloud CLI (gcloud) インストール済み
- Terraform インストール済み
- GCPプロジェクト（課金有効）
- GitHub Personal Access Token（repo権限）
- Git / GitHub リポジトリ設定済み

## 別プロジェクトへの適用

既存のterraformを別のGCPプロジェクトに適用する場合、tfstateを削除してからStep 1へ進む。
tfvarsを変えるだけでは不十分。tfstateを削除しないと、既存プロジェクトのリソースを変更/削除しようとして失敗する。

**Bash / macOS / Linux:**
```bash
cd terraform
rm -f terraform.tfstate terraform.tfstate.backup
```

**PowerShell (Windows):**
```powershell
cd terraform
Remove-Item -Force terraform.tfstate, terraform.tfstate.backup -ErrorAction SilentlyContinue
```

## Step 1: GCP認証

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

## Step 2: terraform.tfvars 作成

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` を編集：

```hcl
gcp_project_id        = "プロジェクトID"
gcp_region            = "asia-northeast1"
environments          = ["dev", "prod"]
alert_recipient_email = "メールアドレス"
github_repository_url = "https://github.com/org/リポジトリ.git"
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

## Step 5: Dataform 手動設定

Terraformでは未サポートのため、以下を手動で実行する。

### 5-1. Strict Act-As モード有効化

```bash
gcloud dataform repositories update hyperliquid-dataform \
  --region=asia-northeast1 \
  --set-authenticated-user-admin
```

### 5-2. リリース構成の初回コンパイル

Terraformで作成されるリリース構成はスケジュール設定を含まないため、初回は手動でコンパイルを実行する。

**Cloud Consoleから:**
1. Cloud Console → Dataform → hyperliquid-dataform リポジトリ
2. 「リリースとスケジュール」タブ
3. 対象のリリース構成（dev / prod）を選択
4. 「コンパイル」をクリック

**gcloud CLI:**
```bash
gcloud dataform compilation-results create \
  --repository=hyperliquid-dataform \
  --region=asia-northeast1 \
  --release-config=prod
```

## Step 6: 動作確認

### GCPコンソールで確認

| リソース | 確認場所 | 確認内容 |
|---------|---------|---------|
| Cloud Functions | Cloud Run Functions | `ingest-hyperliquid` が作成されている |
| BigQuery | BigQuery | データセット（`src_hyperliquid`, `stg_hyperliquid`, `stg_hyperliquid_dev` 等）が作成されている |
| Dataform | Dataform | `hyperliquid-dataform` リポジトリが作成されている |
| Cloud Scheduler | Cloud Scheduler | `ingest-hyperliquid-daily` が作成されている |

## Step 7: 手動テスト

### Cloud Functions（データ取り込み）

**デプロイ後の手動実行（当日分）:**
```bash
gcloud functions call ingest-hyperliquid --region=asia-northeast1
```

**期間指定で実行（過去データ取得）:**

Cloud Functions Gen2は認証が必要。認証トークン付きでcurlを実行する。

Bash / macOS / Linux:
```bash
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  "https://asia-northeast1-<PROJECT_ID>.cloudfunctions.net/ingest-hyperliquid?start_date=2025-10-01&end_date=2025-10-31"
```

PowerShell (Windows):
```powershell
curl.exe -H "Authorization: Bearer $(gcloud auth print-identity-token)" `
  "https://asia-northeast1-<PROJECT_ID>.cloudfunctions.net/ingest-hyperliquid?start_date=2025-10-01&end_date=2025-10-31"
```

### Dataform（SQLワークフロー）

1. GCPコンソール → Dataform → `hyperliquid-dataform`
2. Workspaces → 新規作成 or 既存選択
3. Start Execution → Execute all

## 補足: アーキテクチャ

```
HyperLiquid API
        ↓ Cloud Functions (02:00)
src_hyperliquid.candle_1h
        ↓ Dataform Workflow (03:00)
stg_hyperliquid.candle_1h (重複除去ビュー)
        ↓
int_coin_trend.candle_1h (技術指標算出)
        ↓
mart_coin_trend.fact_candle_1h + mart_shared.dim_calendar
        ↓
Looker Studio
```

Terraformが `git_remote_settings` でGitHubリポジトリを参照するため、Dataform専用リポジトリの作成は不要。

## スケジュール

| ジョブ | 実行時刻 (JST) | 内容 |
|-------|---------------|------|
| Cloud Scheduler | 毎日 02:00 | HyperLiquid API → BigQuery (src_hyperliquid) |
| Dataform Workflow | 毎日 03:00 | stg → int → mart 変換 |

## トラブルシューティング

### Cloud Functionsビルドエラー

Cloud Build サービスアカウントのIAM伝播に時間がかかる場合があります。
Terraformでは120秒のwaitを入れていますが、エラーが発生した場合は再度 `terraform apply` を実行してください。

### Dataformコンパイルエラー

- workflow_settings.yaml の `defaultProject` がプロジェクトIDと一致しているか確認
- GitHub トークンが有効か確認（Secret Manager）
- リポジトリのmainブランチに最新コードがpushされているか確認

### 権限エラー

strict act-as モードが有効な場合、Dataform操作を行うユーザーは `dataform-hyperliquid` サービスアカウントへの `roles/iam.serviceAccountUser` が必要です。

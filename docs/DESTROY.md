# Destroy手順

本ドキュメントは、Terraformで管理するGCPリソースを完全に削除する手順を記載する。

## 前提条件

- `gcloud auth application-default login` 済み
- Terraformがインストール済み
- 対象プロジェクトへのオーナー権限

## 削除手順

### Step 1: Dataformリソースの手動削除（Cloud Console）

Dataformリポジトリは子リソース（Release Config、Workflow Config）を持つため、Terraformでの削除に失敗する。
`gcloud dataform` コマンドは存在しないため、Cloud Console から手動削除を行う。

1. [Cloud Console Dataform](https://console.cloud.google.com/bigquery/dataform) にアクセス
2. リージョン `asia-northeast1` を選択
3. `analytics-dataform` リポジトリをクリック
4. 「リリースとスケジュール」タブを開く
5. **Workflow Config（prod）を削除**：該当行の「︙」→「削除」
6. **Release Config（prod）を削除**：該当行の「︙」→「削除」
7. リポジトリ一覧に戻る
8. **Repository を削除**：`analytics-dataform` の「︙」→「削除」

### Step 2: Terraform stateからDataformリソースを除外

手動削除したリソースをstateから除外する。

```bash
cd terraform

terraform state rm google_dataform_repository_workflow_config.prod
terraform state rm google_dataform_repository_release_config.prod
terraform state rm google_dataform_repository.analytics_dataform
```

state内のリソース名を確認するには：

```bash
terraform state list | grep dataform
```

### Step 3: terraform destroy実行

残りのリソースを削除する。

```bash
terraform destroy
```

**注**: `candle_1h` テーブルは `deletion_protection = false` により削除可能になっている。

## トラブルシューティング

### Dataform削除エラー: "has nested resources"

Step 1を実行せずに`terraform destroy`を実行した場合に発生。Step 1の手順でCloud Consoleから削除する。

### BigQueryデータセット削除エラー: "still in use"

Dataformが作成したビュー/テーブルがデータセット内に残っている場合に発生する。
`delete_contents_on_destroy = true` はTerraformがデータセットを削除する際に中身も消すオプションだが、
Dataformが作成したオブジェクトはTerraformのstateに含まれないため、削除順序の問題で「まだ使用中」エラーが発生する。

**解決策**: `terraform destroy` の前にBigQueryデータセットを手動削除する。

**Bash / macOS / Linux:**
```bash
PROJECT_ID="your-gcp-project-id"

bq rm -r -f ${PROJECT_ID}:src_hyperliquid
bq rm -r -f ${PROJECT_ID}:stg_hyperliquid
bq rm -r -f ${PROJECT_ID}:stg_hyperliquid_dev
bq rm -r -f ${PROJECT_ID}:int_coin_trend
bq rm -r -f ${PROJECT_ID}:int_coin_trend_dev
bq rm -r -f ${PROJECT_ID}:mart_coin_trend
bq rm -r -f ${PROJECT_ID}:mart_coin_trend_dev
bq rm -r -f ${PROJECT_ID}:mart_shared
bq rm -r -f ${PROJECT_ID}:mart_shared_dev
```

**PowerShell (Windows):**
```powershell
$PROJECT_ID = "your-gcp-project-id"

bq rm -r -f ${PROJECT_ID}:src_hyperliquid
bq rm -r -f ${PROJECT_ID}:stg_hyperliquid
bq rm -r -f ${PROJECT_ID}:stg_hyperliquid_dev
bq rm -r -f ${PROJECT_ID}:int_coin_trend
bq rm -r -f ${PROJECT_ID}:int_coin_trend_dev
bq rm -r -f ${PROJECT_ID}:mart_coin_trend
bq rm -r -f ${PROJECT_ID}:mart_coin_trend_dev
bq rm -r -f ${PROJECT_ID}:mart_shared
bq rm -r -f ${PROJECT_ID}:mart_shared_dev
```

または Cloud Console から各データセットを手動削除する。

データセット削除後、Terraform stateから除外する。

**Bash / macOS / Linux:**
```bash
cd terraform

terraform state rm 'google_bigquery_dataset.sources'
terraform state rm 'google_bigquery_table.candle_1h'
terraform state rm 'google_bigquery_dataset.staging["dev"]'
terraform state rm 'google_bigquery_dataset.staging["prod"]'
terraform state rm 'google_bigquery_dataset.intermediate["dev"]'
terraform state rm 'google_bigquery_dataset.intermediate["prod"]'
terraform state rm 'google_bigquery_dataset.marts_analytics["dev"]'
terraform state rm 'google_bigquery_dataset.marts_analytics["prod"]'
terraform state rm 'google_bigquery_dataset.marts_shared["dev"]'
terraform state rm 'google_bigquery_dataset.marts_shared["prod"]'
```

**PowerShell (Windows):**
```powershell
cd terraform

terraform state rm "google_bigquery_dataset.sources"
terraform state rm "google_bigquery_table.candle_1h"
terraform state rm "google_bigquery_dataset.staging[\`"dev\`"]"
terraform state rm "google_bigquery_dataset.staging[\`"prod\`"]"
terraform state rm "google_bigquery_dataset.intermediate[\`"dev\`"]"
terraform state rm "google_bigquery_dataset.intermediate[\`"prod\`"]"
terraform state rm "google_bigquery_dataset.marts_analytics[\`"dev\`"]"
terraform state rm "google_bigquery_dataset.marts_analytics[\`"prod\`"]"
terraform state rm "google_bigquery_dataset.marts_shared[\`"dev\`"]"
terraform state rm "google_bigquery_dataset.marts_shared[\`"prod\`"]"
```

その後 `terraform destroy` を実行する

### BigQueryテーブル削除エラー: "deletion_protection"

`deletion_protection = false` に変更後、`terraform apply` を実行してからdestroyを行う。

```bash
terraform apply -target=google_bigquery_table.candle_1h
terraform destroy
```

### state rmでリソースが見つからない

`terraform state list` でリソース名を確認する。

```bash
# 全リソース一覧
terraform state list

# Dataform関連のみ
terraform state list | grep dataform

# 特定リソースの詳細
terraform state show google_dataform_repository.analytics_dataform
```

## クリーンアップ

### Terraform backupファイルの削除

`terraform apply` や `terraform destroy` を実行すると、`terraform.tfstate.*.backup` ファイルが生成される。
destroy完了後、これらは不要なので削除する。

**Bash / macOS / Linux:**
```bash
cd terraform
rm -f terraform.tfstate.*.backup terraform.tfstate.backup
```

**PowerShell (Windows):**
```powershell
cd terraform
Remove-Item terraform.tfstate.*.backup, terraform.tfstate.backup -ErrorAction SilentlyContinue
```

## 再デプロイ

リソースを再作成する場合は [DEPLOYMENT.md](DEPLOYMENT.md) を参照。

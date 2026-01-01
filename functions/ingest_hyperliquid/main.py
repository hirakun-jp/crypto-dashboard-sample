import functions_framework
import requests
import pandas as pd
from datetime import datetime, timedelta, timezone
from google.cloud import bigquery
import time

COINS = ["BTC", "ETH", "DOGE"]
INTERVAL = "1h"
API_URL = "https://api.hyperliquid.xyz/info"


def fetch_candles(coin: str, start_ts: int, end_ts: int) -> pd.DataFrame | None:
    headers = {"Content-Type": "application/json"}
    payload = {
        "type": "candleSnapshot",
        "req": {
            "coin": coin,
            "interval": INTERVAL,
            "startTime": start_ts,
            "endTime": end_ts,
        },
    }

    res = requests.post(API_URL, headers=headers, json=payload, timeout=30)
    res.raise_for_status()

    data = res.json()
    if isinstance(data, list) and len(data) > 0:
        if isinstance(data[0], dict):
            candles = data
        elif isinstance(data[0], list):
            candles = data[0]
        else:
            return None
    else:
        return None

    if not candles:
        return None

    df = pd.DataFrame(candles)
    df["time"] = pd.to_datetime(df["t"], unit="ms")
    df = df[["time", "o", "h", "l", "c", "v", "n", "s"]]
    df.columns = ["time", "open", "high", "low", "close", "volume", "num_trades", "symbol"]
    df["open"] = df["open"].astype(float)
    df["high"] = df["high"].astype(float)
    df["low"] = df["low"].astype(float)
    df["close"] = df["close"].astype(float)
    df["volume"] = df["volume"].astype(float)
    df["num_trades"] = df["num_trades"].astype(int)
    return df.sort_values("time")


def load_to_bigquery(df: pd.DataFrame, project_id: str, dataset_id: str, table_id: str):
    client = bigquery.Client(project=project_id)
    table_ref = f"{project_id}.{dataset_id}.{table_id}"

    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        schema=[
            bigquery.SchemaField("time", "TIMESTAMP"),
            bigquery.SchemaField("open", "FLOAT64"),
            bigquery.SchemaField("high", "FLOAT64"),
            bigquery.SchemaField("low", "FLOAT64"),
            bigquery.SchemaField("close", "FLOAT64"),
            bigquery.SchemaField("volume", "FLOAT64"),
            bigquery.SchemaField("num_trades", "INT64"),
            bigquery.SchemaField("symbol", "STRING"),
        ],
    )

    job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
    job.result()
    print(f"Loaded {len(df)} rows to {table_ref}")


@functions_framework.http
def ingest_hyperliquid(request):
    import os

    project_id = os.environ.get("GCP_PROJECT_ID")
    dataset_id = os.environ.get("BQ_DATASET_ID", "src_hyperliquid")

    yesterday = datetime.now(timezone.utc).date() - timedelta(days=1)
    start_dt = datetime(yesterday.year, yesterday.month, yesterday.day, tzinfo=timezone.utc)
    end_dt = start_dt + timedelta(days=1)

    start_ts = int(start_dt.timestamp() * 1000)
    end_ts = int(end_dt.timestamp() * 1000) - 1

    results = []
    for coin in COINS:
        try:
            time.sleep(1.0)
            df = fetch_candles(coin, start_ts, end_ts)
            if df is not None and not df.empty:
                load_to_bigquery(df, project_id, dataset_id, "candle_1h")
                results.append(f"{coin}: {len(df)} rows")
            else:
                results.append(f"{coin}: no data")
        except Exception as e:
            results.append(f"{coin}: error - {str(e)}")

    return {"status": "completed", "date": str(yesterday), "results": results}

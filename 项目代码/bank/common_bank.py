# -*- coding: utf-8 -*-
"""Shared configuration and helpers for the UCI Bank Marketing pipeline."""
import json
import os

from pyspark.sql import SparkSession
from pyspark.sql.types import IntegerType, LongType, StringType, StructField, StructType

BASE = os.environ.get("BIGDATA_BASE", "hdfs://master:9000/bigdata")
RAW = os.environ.get("BANK_RAW", BASE + "/raw/bank_marketing/bank-full.csv")
ODS = os.environ.get("BANK_ODS", BASE + "/ods/bank_marketing")
OUT_LOCAL = os.environ.get("BIGDATA_OUT", "/opt/bigdata-course/output/web")


def get_spark(app):
    spark = (
        SparkSession.builder.appName(app)
        .config("spark.sql.shuffle.partitions", os.environ.get("SHUFFLE_PARTITIONS", "8"))
        .config("spark.sql.adaptive.enabled", "true")
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
        .config("spark.driver.maxResultSize", "512m")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel(os.environ.get("LOG_LEVEL", "WARN"))
    return spark


def schema():
    return StructType([
        StructField("age", IntegerType(), True),
        StructField("job", StringType(), True),
        StructField("marital", StringType(), True),
        StructField("education", StringType(), True),
        StructField("default", StringType(), True),
        StructField("balance", LongType(), True),
        StructField("housing", StringType(), True),
        StructField("loan", StringType(), True),
        StructField("contact", StringType(), True),
        StructField("day", IntegerType(), True),
        StructField("month", StringType(), True),
        StructField("duration", IntegerType(), True),
        StructField("campaign", IntegerType(), True),
        StructField("pdays", IntegerType(), True),
        StructField("previous", IntegerType(), True),
        StructField("poutcome", StringType(), True),
        StructField("y", StringType(), True),
    ])


def read_raw(spark):
    return (
        spark.read.option("header", "true")
        .option("sep", ";")
        .option("quote", '"')
        .option("encoding", "UTF-8")
        .option("mode", "FAILFAST")
        .schema(schema())
        .csv(RAW)
    )


def stage(message):
    print("\n" + "=" * 72)
    print(">>> " + message)
    print("=" * 72, flush=True)


def save_json(obj, name):
    os.makedirs(OUT_LOCAL, exist_ok=True)
    path = os.path.join(OUT_LOCAL, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2, default=str)
    print(f"[output] {path}", flush=True)
    return path


def save_csv(df, name, limit=5000):
    os.makedirs(OUT_LOCAL, exist_ok=True)
    path = os.path.join(OUT_LOCAL, name)
    df.limit(limit).toPandas().to_csv(path, index=False, encoding="utf-8-sig")
    print(f"[output] {path}", flush=True)
    return path

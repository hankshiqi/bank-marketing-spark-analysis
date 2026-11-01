# -*- coding: utf-8 -*-
"""Clean the source and write month-partitioned Parquet to HDFS."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common_bank as C
from pyspark.sql import functions as F


def main():
    spark = C.get_spark("bank-02-to-parquet")
    C.stage(f"读取 {C.RAW}")
    raw = C.read_raw(spark)
    before = raw.count()

    strings = ["job", "marital", "education", "default", "housing", "loan",
               "contact", "month", "poutcome", "y"]
    clean = raw
    for col in strings:
        clean = clean.withColumn(col, F.trim(F.col(col)))
    clean = (
        clean.dropDuplicates()
        .filter(F.col("age").isNotNull() & (F.col("age") > 0))
        .filter(F.col("y").isin("yes", "no"))
        .withColumn("subscribed_label", F.when(F.col("y") == "yes", 1).otherwise(0))
        .withColumn(
            "age_group",
            F.when(F.col("age") < 30, "under_30")
             .when(F.col("age") < 45, "30_to_44")
             .when(F.col("age") < 60, "45_to_59")
             .otherwise("60_plus"),
        )
    )
    after = clean.count()
    C.stage(f"写入按 month 分区的 Parquet: {C.ODS}")
    clean.repartition("month").write.mode("overwrite").partitionBy("month").parquet(C.ODS)

    check = spark.read.parquet(C.ODS)
    restored = check.count()
    partitions = check.select("month").distinct().count()
    print(f"源数据行数: {before:,}")
    print(f"清洗后行数: {after:,}，去重/过滤: {before - after:,}")
    print(f"Parquet 回读行数: {restored:,}，一致: {restored == after}")
    print(f"月份分区数: {partitions}")
    check.groupBy("y").count().orderBy(F.desc("count")).show()
    C.save_json({
        "dataset": "UCI Bank Marketing",
        "source_rows": before,
        "clean_rows": after,
        "removed_rows": before - after,
        "parquet_path": C.ODS,
        "month_partitions": partitions,
        "readback_matches": restored == after,
    }, "bank_etl_summary.json")
    if restored != after:
        raise RuntimeError("Parquet 回读行数与清洗后行数不一致")
    print("[OK] Bank Marketing 清洗与 Parquet 入湖完成")
    spark.stop()


if __name__ == "__main__":
    main()

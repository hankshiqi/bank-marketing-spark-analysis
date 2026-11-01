# -*- coding: utf-8 -*-
"""Validate the complete UCI Bank Marketing source file with Spark."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common_bank as C
from pyspark.sql import functions as F


def main():
    spark = C.get_spark("bank-01-profile")
    C.stage(f"读取完整数据集 {C.RAW}")
    df = C.read_raw(spark).cache()
    total = df.count()
    distinct = df.dropDuplicates().count()
    nulls = df.select([
        F.count(F.when(F.col(c).isNull(), c)).alias(c) for c in df.columns
    ]).first().asDict()
    labels = {r["y"]: r["count"] for r in df.groupBy("y").count().collect()}

    print(f"数据行数: {total:,}")
    print(f"字段数: {len(df.columns)}")
    print(f"重复行数: {total - distinct:,}")
    print("空值统计:", nulls)
    print("标签分布:", labels)
    df.select("age", "balance", "campaign", "previous").describe().show(truncate=False)

    profile = {
        "dataset": "UCI Bank Marketing",
        "source": "https://archive.ics.uci.edu/dataset/222/bank+marketing",
        "raw_path": C.RAW,
        "rows": total,
        "columns": df.columns,
        "duplicate_rows": total - distinct,
        "nulls": nulls,
        "subscription_distribution": {str(k): int(v) for k, v in labels.items()},
    }
    C.save_json(profile, "bank_profile.json")
    if total != 45211 or distinct != total or any(nulls.values()):
        raise RuntimeError("源数据完整性检查未通过；请核对官方文件与 CSV 解析参数")
    print("[OK] 全量数据体检通过: 45,211 行 / 17 字段 / 无空值 / 无重复")
    spark.stop()


if __name__ == "__main__":
    main()

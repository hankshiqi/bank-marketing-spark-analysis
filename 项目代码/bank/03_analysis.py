# -*- coding: utf-8 -*-
"""Spark SQL business metrics and label-free KMeans customer segments."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common_bank as C
from pyspark.ml.clustering import KMeans
from pyspark.ml.feature import StandardScaler, VectorAssembler
from pyspark.sql import functions as F


def main():
    spark = C.get_spark("bank-03-analysis")
    C.stage(f"读取 Parquet {C.ODS}")
    df = spark.read.parquet(C.ODS).cache()
    df.createOrReplaceTempView("bank_marketing")

    C.stage("Spark SQL: 总体转化率、职业、月份、联系方式與触达次数")
    overall = spark.sql("""
        SELECT COUNT(*) AS records,
               SUM(CASE WHEN y = 'yes' THEN 1 ELSE 0 END) AS subscribed,
               AVG(subscribed_label) AS conversion_rate
        FROM bank_marketing
    """)
    overall.show(truncate=False)
    by_job = spark.sql("""
        SELECT job, COUNT(*) AS records,
               SUM(subscribed_label) AS subscribed,
               AVG(subscribed_label) AS conversion_rate
        FROM bank_marketing GROUP BY job ORDER BY conversion_rate DESC
    """)
    by_month = spark.sql("""
        SELECT month, COUNT(*) AS records,
               SUM(subscribed_label) AS subscribed,
               AVG(subscribed_label) AS conversion_rate
        FROM bank_marketing GROUP BY month ORDER BY month
    """)
    by_contact = spark.sql("""
        SELECT contact, COUNT(*) AS records,
               SUM(subscribed_label) AS subscribed,
               AVG(subscribed_label) AS conversion_rate
        FROM bank_marketing GROUP BY contact ORDER BY conversion_rate DESC
    """)
    campaign = (
        df.withColumn("campaign_band", F.when(F.col("campaign") <= 2, "1-2")
                      .when(F.col("campaign") <= 5, "3-5").otherwise("6+"))
        .groupBy("campaign_band")
        .agg(F.count("*").alias("records"),
             F.sum("subscribed_label").alias("subscribed"),
             F.avg("subscribed_label").alias("conversion_rate"))
        .orderBy("campaign_band")
    )
    by_job.show(20, truncate=False)
    by_month.show(20, truncate=False)
    by_contact.show(truncate=False)
    campaign.show(truncate=False)
    C.save_csv(by_job, "bank_job_kpi.csv")
    C.save_csv(by_month, "bank_month_kpi.csv")
    C.save_csv(by_contact, "bank_contact_kpi.csv")
    C.save_csv(campaign, "bank_campaign_kpi.csv")

    C.stage("KMeans: 按客户数值特征分群，不把 y 标签作为输入")
    feature_cols = ["age", "balance", "campaign", "previous"]
    assembled = VectorAssembler(inputCols=feature_cols, outputCol="features_raw").transform(df)
    scaled = StandardScaler(inputCol="features_raw", outputCol="features",
                            withMean=True, withStd=True).fit(assembled).transform(assembled)
    model = KMeans(k=3, seed=42, maxIter=30, featuresCol="features",
                   predictionCol="cluster").fit(scaled)
    clustered = model.transform(scaled)
    summary = (
        clustered.groupBy("cluster")
        .agg(F.count("*").alias("records"),
             F.avg("age").alias("avg_age"),
             F.avg("balance").alias("avg_balance"),
             F.avg("campaign").alias("avg_campaign_contacts"),
             F.avg("subscribed_label").alias("conversion_rate"))
        .orderBy("cluster")
    )
    summary.show(truncate=False)
    C.save_csv(summary, "bank_cluster_summary.csv")
    C.save_json({"dataset": "UCI Bank Marketing", "k": 3,
                 "training_rows": df.count(),
                 "features": feature_cols,
                 "target_used_as_feature": False,
                 "training_cost": float(model.summary.trainingCost)},
                "bank_kmeans.json")
    print("[OK] Bank Marketing Spark SQL 与 KMeans 分析完成")
    spark.stop()


if __name__ == "__main__":
    main()

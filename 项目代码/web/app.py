# -*- coding: utf-8 -*-
"""
步骤 10：可视化 Web 服务（Flask + ECharts）

数据来源：/opt/bigdata-course/output/web 下由各 Spark 作业导出的 json / csv。
访问：http://<EIP>:8000

启动：
    nohup python web/app.py > ../logs/web.log 2>&1 &
"""
import csv
import glob
import json
import os
import sys

from flask import Flask, jsonify, render_template, send_from_directory

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DATA = os.environ.get("BIGDATA_OUT", "/opt/bigdata-course/output/web")
HERE = os.path.dirname(os.path.abspath(__file__))

app = Flask(__name__,
            template_folder=os.path.join(HERE, "templates"),
            static_folder=os.path.join(HERE, "static"))


def _json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _csv(path):
    with open(path, "r", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def _asset(filename):
    """Read the live output name or the date-prefixed local evidence copy."""
    path = os.path.join(DATA, filename)
    if os.path.isfile(path):
        return path
    matches = sorted(glob.glob(os.path.join(DATA, "????-??-??_" + filename)))
    return matches[-1] if matches else None


def _json_optional(filename):
    path = _asset(filename)
    return _json(path) if path else None


def _csv_optional(filename):
    path = _asset(filename)
    return _csv(path) if path else []


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/<name>")
def api(name):
    """通用取数接口：优先同名 json，其次同名 csv。"""
    safe = os.path.basename(name)
    j = _asset(safe + ".json")
    if j:
        return jsonify(_json(j))
    c = _asset(safe + ".csv")
    if c:
        return jsonify(_csv(c))
    return jsonify([])


@app.route("/api/bank/summary")
def bank_summary():
    return jsonify({
        "profile": _json_optional("bank_profile.json"),
        "etl": _json_optional("bank_etl_summary.json"),
        "model": _json_optional("bank_kmeans.json"),
        "campaign": _csv_optional("bank_campaign_kpi.csv"),
        "month": _csv_optional("bank_month_kpi.csv"),
        "job": _csv_optional("bank_job_kpi.csv"),
        "contact": _csv_optional("bank_contact_kpi.csv"),
        "clusters": _csv_optional("bank_cluster_summary.csv"),
    })


@app.route("/api/status")
def status():
    files = sorted(os.listdir(DATA)) if os.path.isdir(DATA) else []
    return jsonify({"data_dir": DATA, "files": files, "count": len(files)})


@app.route("/favicon.ico")
def favicon():
    return send_from_directory(app.static_folder, "favicon.ico") if os.path.exists(
        os.path.join(app.static_folder, "favicon.ico")) else ("", 204)


if __name__ == "__main__":
    port = int(os.environ.get("WEB_PORT", "8000"))
    print(f"[info] 数据目录: {DATA}  文件数: {len(os.listdir(DATA)) if os.path.isdir(DATA) else 0}")
    app.run(host="0.0.0.0", port=port, debug=False)

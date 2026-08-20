from flask import Flask, request, Response
import os
import psycopg2
import boto3
import requests
import time
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

APP_VERSION = os.getenv("APP_VERSION", "unknown")
GIT_SHA = os.getenv("GIT_SHA", "unknown")
RELEASE = os.getenv("RELEASE", "unknown")

DB_HOST = os.getenv("DB_HOST")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_PORT = os.getenv("DB_PORT", "5432")

S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME")
SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
WORKER_URL = os.getenv("WORKER_URL", "http://worker-service:5001")

HTTP_REQUESTS = Counter(
    "app_http_requests_total",
    "Total HTTP requests",
    ["service", "method", "route", "status", "release"]
)

HTTP_REQUEST_DURATION = Histogram(
    "app_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["service", "method", "route", "release"]
)

DEPENDENCY_FAILURES = Counter(
    "app_dependency_failures_total",
    "Total dependency failures",
    ["service", "dependency"]
)

MACHINES_CREATED = Counter(
    "app_machines_created_total",
    "Total machines created successfully"
)

APP_INFO = Gauge(
    "app_info",
    "Application release information",
    ["service", "version", "git_sha", "release"]
)

APP_INFO.labels(
    service="backend",
    version=APP_VERSION,
    git_sha=GIT_SHA,
    release=RELEASE
).set(1)


s3 = boto3.client("s3", region_name=AWS_REGION)
sns = boto3.client("sns", region_name=AWS_REGION)

def get_connection():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )

def init_db():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS items (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100),
            os VARCHAR(100),
            cpu INTEGER,
            ram_gb INTEGER
        );
    """)
    conn.commit()
    cur.close()
    conn.close()


@app.before_request
def start_request_timer():
    request._prometheus_start_time = time.perf_counter()


@app.after_request
def record_request_metrics(response):
    if request.path == "/metrics":
        return response

    route = request.url_rule.rule if request.url_rule else "unmatched"
    duration = time.perf_counter() - request._prometheus_start_time

    HTTP_REQUESTS.labels(
        service="backend",
        method=request.method,
        route=route,
        status=str(response.status_code),
        release=RELEASE
    ).inc()

    HTTP_REQUEST_DURATION.labels(
        service="backend",
        method=request.method,
        route=route,
        release=RELEASE
    ).observe(duration)

    return response


@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.route("/")
def home():
    return "Backend API is running with RDS, S3 and SNS"

@app.route("/health")
def health():
    return {"status": "healthy", "service": "backend"}

@app.route("/worker")
def worker():
    try:
        response = requests.get(f"{WORKER_URL}/health", timeout=5)
        response.raise_for_status()
        return response.json()
    except requests.RequestException:
        DEPENDENCY_FAILURES.labels(
            service="backend",
            dependency="worker"
        ).inc()
        raise

@app.route("/provision", methods=["POST"])
def provision():
    data = request.json or {}

    name = data.get("name", "demo-vm")
    os_name = data.get("os", "ubuntu-22.04-lts")
    cpu = int(data.get("cpu", 2))
    ram_gb = int(data.get("ram_gb", 4))

    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        cur.execute(
            "INSERT INTO items (name, os, cpu, ram_gb) VALUES (%s, %s, %s, %s)",
            (name, os_name, cpu, ram_gb)
        )

        conn.commit()

    except Exception:
        DEPENDENCY_FAILURES.labels(
            service="backend",
            dependency="rds"
        ).inc()
        raise

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    MACHINES_CREATED.inc()

    return {"status": "added"}

@app.route("/machines")
def machines():
    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        cur.execute(
            "SELECT id, name, os, cpu, ram_gb FROM items ORDER BY id"
        )
        rows = cur.fetchall()

    except Exception:
        DEPENDENCY_FAILURES.labels(
            service="backend",
            dependency="rds"
        ).inc()
        raise

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    items = []

    for row in rows:
        items.append({
            "id": row[0],
            "name": row[1],
            "os": row[2],
            "cpu": row[3],
            "ram_gb": row[4]
        })

    return {"items": items}

@app.route("/upload", methods=["POST"])
def upload():
    conn = None
    cur = None

    try:
        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT id, name, os, cpu, ram_gb
            FROM items
            ORDER BY id DESC
            LIMIT 1
        """)

        row = cur.fetchone()

    except Exception:
        DEPENDENCY_FAILURES.labels(
            service="backend",
            dependency="rds"
        ).inc()
        raise

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

    if not row:
        return {"status": "error", "message": "No machines found"}, 400

    vm_id, name, os_name, cpu, ram_gb = row

    filename = f"vm-report-{vm_id}.txt"

    content = f"""
VM Provisioning Report

Machine ID: {vm_id}
Name: {name}
Operating System: {os_name}
CPU: {cpu}
RAM: {ram_gb}GB
"""

    try:
        s3.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=filename,
            Body=content
        )
    except Exception:
        DEPENDENCY_FAILURES.labels(
            service="backend",
            dependency="s3"
        ).inc()
        raise

    try:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject="VM Report Uploaded",
            Message=f"VM report {filename} was uploaded to S3."
        )
    except Exception:
        DEPENDENCY_FAILURES.labels(
            service="backend",
            dependency="sns"
        ).inc()
        raise

    return {
        "status": "uploaded",
        "bucket": S3_BUCKET_NAME,
        "file": filename,
        "sns": "notification sent"
    }


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)
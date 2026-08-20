from flask import Flask, request, Response
import os
import time
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    CollectorRegistry,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
)

app = Flask(__name__)

REGISTRY = CollectorRegistry()

APP_VERSION = os.getenv("APP_VERSION", "unknown")
GIT_SHA = os.getenv("GIT_SHA", "unknown")
RELEASE = os.getenv("RELEASE", "unknown")

HTTP_REQUESTS = Counter(
    "app_http_requests_total",
    "Total HTTP requests",
    ["service", "method", "route", "status", "release"],
    registry=REGISTRY
)

HTTP_REQUEST_DURATION = Histogram(
    "app_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["service", "method", "route", "release"],
    registry=REGISTRY
)

PROCESS_OPERATIONS = Counter(
    "app_worker_process_total",
    "Total worker process operations",
    registry=REGISTRY
)

APP_INFO = Gauge(
    "app_info",
    "Application release information",
    ["service", "version", "git_sha", "release"],
    registry=REGISTRY
)

APP_INFO.labels(
    service="worker",
    version=APP_VERSION,
    git_sha=GIT_SHA,
    release=RELEASE
).set(1)


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
        service="worker",
        method=request.method,
        route=route,
        status=str(response.status_code),
        release=RELEASE
    ).inc()

    HTTP_REQUEST_DURATION.labels(
        service="worker",
        method=request.method,
        route=route,
        release=RELEASE
    ).observe(duration)

    return response


@app.route("/metrics")
def metrics():
    return Response(generate_latest(REGISTRY), mimetype=CONTENT_TYPE_LATEST)


@app.route("/")
def home():
    return "Worker service is running"


@app.route("/health")
def health():
    return {"status": "healthy", "service": "worker"}


@app.route("/process")
def process():
    PROCESS_OPERATIONS.inc()
    return {"status": "processed"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)

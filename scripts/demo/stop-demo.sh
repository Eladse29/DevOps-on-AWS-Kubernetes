#!/usr/bin/env bash

set -u

STATE_DIR="${STATE_DIR:-/tmp/devops-project-demo}"

echo "============================================================"
echo " STOPPING DEVOPS DEMO ENVIRONMENT"
echo "============================================================"

stop_process() {
    local name="$1"
    local pid_file="${STATE_DIR}/${name}.pid"

    if [[ ! -f "${pid_file}" ]]; then
        echo "${name}: not running"
        return
    fi

    pid="$(cat "${pid_file}")"

    if kill -0 "${pid}" >/dev/null 2>&1; then
        echo "Stopping ${name} (PID ${pid})..."
        kill "${pid}" >/dev/null 2>&1 || true

        for _ in $(seq 1 10); do
            if ! kill -0 "${pid}" >/dev/null 2>&1; then
                break
            fi
            sleep 1
        done

        if kill -0 "${pid}" >/dev/null 2>&1; then
            echo "${name}: forcing shutdown..."
            kill -9 "${pid}" >/dev/null 2>&1 || true
        fi
    else
        echo "${name}: already stopped"
    fi

    rm -f "${pid_file}"
}

stop_process ngrok
stop_process grafana
stop_process prometheus
stop_process jenkins-webhook
stop_process jenkins-ui

echo
echo "===== PORT CHECK ====="

for port in 3000 8080 9090 18080; do
    if curl \
        --silent \
        --max-time 1 \
        "http://127.0.0.1:${port}" \
        >/dev/null 2>&1
    then
        echo "WARNING: localhost:${port} is still responding"
    else
        echo "localhost:${port}: stopped"
    fi
done

echo
echo "============================================================"
echo " DEMO ENVIRONMENT STOPPED"
echo "============================================================"

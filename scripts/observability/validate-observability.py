from pathlib import Path
import json
import yaml

ROOT = Path(".")

required_files = [
    ROOT / "observability/values/kube-prometheus-stack-values.yaml",
    ROOT / "observability/monitors/backend-servicemonitor.yaml",
    ROOT / "observability/monitors/frontend-servicemonitor.yaml",
    ROOT / "observability/monitors/worker-servicemonitor.yaml",
    ROOT / "observability/monitors/jenkins-servicemonitor.yaml",
    ROOT / "observability/rules/task5-alerts.yaml",
    ROOT / "observability/dashboards/application-overview.json",
    ROOT / "observability/dashboards/kubernetes-cluster.json",
    ROOT / "observability/dashboards/jenkins-delivery.json",
]

for path in required_files:
    if not path.is_file():
        raise SystemExit(f"ERROR: missing required observability file: {path}")

for path in sorted((ROOT / "observability/monitors").glob("*.yaml")):
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if data.get("apiVersion") != "monitoring.coreos.com/v1":
        raise SystemExit(f"ERROR: invalid apiVersion in {path}")
    if data.get("kind") != "ServiceMonitor":
        raise SystemExit(f"ERROR: expected ServiceMonitor in {path}")

rules_path = ROOT / "observability/rules/task5-alerts.yaml"
rules = yaml.safe_load(rules_path.read_text(encoding="utf-8"))

if rules.get("kind") != "PrometheusRule":
    raise SystemExit("ERROR: task5-alerts.yaml is not a PrometheusRule")

alerts = [
    rule
    for group in rules["spec"]["groups"]
    for rule in group["rules"]
]

if len(alerts) < 6:
    raise SystemExit("ERROR: at least six alert rules are required")

for rule in alerts:
    annotations = rule.get("annotations", {})
    labels = rule.get("labels", {})

    for field in ["summary", "description", "runbook_url"]:
        if not annotations.get(field):
            raise SystemExit(
                f"ERROR: alert {rule.get('alert')} missing annotation {field}"
            )

    if not labels.get("severity"):
        raise SystemExit(
            f"ERROR: alert {rule.get('alert')} missing severity"
        )

for path in sorted((ROOT / "observability/dashboards").glob("*.json")):
    dashboard = json.loads(path.read_text(encoding="utf-8"))

    if not dashboard.get("uid"):
        raise SystemExit(f"ERROR: dashboard without uid: {path}")

    if not dashboard.get("title"):
        raise SystemExit(f"ERROR: dashboard without title: {path}")

    if not dashboard.get("panels"):
        raise SystemExit(f"ERROR: dashboard without panels: {path}")

values_path = ROOT / "observability/values/kube-prometheus-stack-values.yaml"
values = yaml.safe_load(values_path.read_text(encoding="utf-8"))

if values["prometheus"]["prometheusSpec"]["retention"] != "7d":
    raise SystemExit("ERROR: Prometheus retention is not configured as expected")

if values["grafana"]["service"]["type"] != "ClusterIP":
    raise SystemExit("ERROR: Grafana must not be publicly exposed")

print("Observability validation passed.")
print(f"ServiceMonitors: {len(list((ROOT / 'observability/monitors').glob('*.yaml')))}")
print(f"Alerts: {len(alerts)}")
print(f"Dashboards: {len(list((ROOT / 'observability/dashboards').glob('*.json')))}")

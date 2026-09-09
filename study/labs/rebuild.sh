#!/usr/bin/env bash
# 관측성 실습 환경 재구축 — 각 단계 문서를 대체하지 않는다. 복원용이다.
set -euo pipefail

ROOT="$HOME/k8s-observability"
CHART_VERSION="88.3.0"

echo "[1/6] 클러스터 생성"
kind create cluster --config "$ROOT/infra/kind-cluster.yaml"

echo "[2/6] 앱 이미지 빌드와 적재"
for app in order-api gateway; do
  (cd "$ROOT/apps/$app" && ./gradlew bootBuildImage)
  kind load docker-image "obs/${app}:0.0.1" --name obs
done

echo "[3/6] 앱 배포"
kubectl apply -f "$ROOT/k8s/00-namespace.yaml"
kubectl apply -f "$ROOT/k8s/10-order-api.yaml"
kubectl apply -f "$ROOT/k8s/20-gateway.yaml"
kubectl -n apps rollout status deploy/order-api --timeout=180s
kubectl -n apps rollout status deploy/gateway --timeout=180s

echo "[4/6] 관측 스택 설치"
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --version "$CHART_VERSION" \
  -f "$ROOT/monitoring/kps-values.yaml" \
  --wait --timeout 15m

echo "[5/6] 연동 리소스"
kubectl apply -f "$ROOT/k8s/monitoring/90-servicemonitors.yaml"
kubectl apply -f "$ROOT/k8s/monitoring/91-prometheusrule.yaml"

echo "[6/6] 대시보드"
kubectl -n monitoring create configmap obs-red-dashboard \
  --from-file=obs-red.json="$ROOT/monitoring/dashboards/obs-red.json" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n monitoring label configmap obs-red-dashboard grafana_dashboard=1 --overwrite
kubectl -n monitoring annotate configmap obs-red-dashboard grafana_folder="Obs Study" --overwrite

echo "완료 — http://localhost:30300 (grafana) · http://localhost:30900 (prometheus)"

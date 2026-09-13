#!/usr/bin/env bash
# course/labs/scripts/rebuild.sh
# 빈 노트북에서 M14 시점 상태까지 한 번에 복구한다.
# 뒤쪽 모듈에서 실습이 꼬였을 때의 탈출구 — 클러스터를 지우고 이것을 돌리면 된다.
#
#   bash course/labs/scripts/rebuild.sh          기존 클러스터를 그대로 쓴다
#   RECREATE=1 bash .../rebuild.sh               클러스터부터 다시 만든다
set -euo pipefail

# 이 스크립트가 있는 위치 기준으로 labs 루트를 잡는다. 어느 디렉터리에서 실행해도 된다.
LABS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="${CLUSTER:-study}"
INGRESS_CHART_VERSION="4.15.1"     # 2026-09-03 확인. 실습 당일 재확인하라
METRICS_SERVER_VERSION="v0.9.0"    # M16 kubectl top · M17 HPA 의 전제. kind 에는 기본으로 없다

step() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

step "1/7 클러스터"
if [ "${RECREATE:-0}" = "1" ]; then
  kind delete cluster --name "$CLUSTER" || true
fi
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "  이미 있다: $CLUSTER"
else
  kind create cluster --config "$LABS/infra/kind-cluster.yaml"
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

step "2/7 애플리케이션 이미지"
# v1 과 v2 를 모두 만든다. M10 롤아웃과 M15 프로브 실습이 두 태그를 쓴다.
for v in v1 v2; do
  docker build -t "journal-api:$v" --build-arg "APP_VERSION=$v" "$LABS/apps/journal-api"
  kind load docker-image "journal-api:$v" --name "$CLUSTER"
done

step "3/7 metrics-server"
# kind 의 kubelet 은 자체 서명 인증서를 쓴다. --kubelet-insecure-tls 없이는 파드가 Ready 가 되지 않는다.
kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"
kubectl patch deploy metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' \
  2>/dev/null || echo "  --kubelet-insecure-tls 는 이미 들어 있다"
kubectl rollout status deploy/metrics-server -n kube-system --timeout=120s

step "4/7 인그레스 컨트롤러"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo update >/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --version "$INGRESS_CHART_VERSION" -f "$LABS/monitoring/ingress-nginx-values.yaml" \
  --wait --timeout 5m

step "5/7 저널 애플리케이션"
# M12 에서 default 네임스페이스에 만든 인그레스가 남아 있으면 호스트·경로가 겹쳐
# ingress-nginx 어드미션 웹훅이 journal 네임스페이스의 인그레스를 거부한다.
# 탈출구 스크립트가 그 잔재 때문에 멈추면 안 되므로 먼저 치운다.
kubectl delete ingress journal        -n default --ignore-not-found
kubectl delete ingress journal-gateway -n default --ignore-not-found
kubectl apply -k "$LABS/k8s/journal"

step "6/7 준비될 때까지 대기"
kubectl rollout status deploy/journal-api -n journal --timeout=180s
kubectl rollout status deploy/web-static  -n journal --timeout=180s
kubectl rollout status statefulset/redis  -n journal --timeout=180s

step "7/7 스모크 테스트"
# 인그레스 컨트롤러가 규칙을 읽을 때까지 잠깐 걸린다.
for i in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -H "Host: journal.local" http://localhost:18080/api/entries || true)
  [ "$code" = "200" ] && break
  sleep 2
done
if [ "${code:-}" != "200" ]; then
  echo "  실패: /api/entries 가 200 을 돌려주지 않는다 (마지막 코드 ${code:-none})" >&2
  exit 1
fi
curl -s -H "Host: journal.local" -X POST http://localhost:18080/api/entries \
  -H 'content-type: application/json' -d '{"text":"rebuild smoke test"}' >/dev/null
echo "  200 OK — $(curl -s -H "Host: journal.local" http://localhost:18080/api/entries)"

printf '\n복구 완료. http://journal.local:18080 (/etc/hosts 에 항목이 있어야 브라우저로 열린다)\n'

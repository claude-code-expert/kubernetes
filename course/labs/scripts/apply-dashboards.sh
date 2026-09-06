#!/usr/bin/env bash
# course/labs/scripts/apply-dashboards.sh
# labs/monitoring/dashboards/*.json 을 그라파나 대시보드 ConfigMap 으로 만든다.
#
#   bash course/labs/scripts/apply-dashboards.sh
#
# 그라파나 사이드카(M19 값 파일의 sidecar.dashboards)가 아래 라벨이 붙은 ConfigMap 을
# 찾아 대시보드로 등록한다. UI 에서 만든 대시보드는 그라파나 파드가 다시 뜨면 사라지지만
# 이것은 매니페스트라 이 스크립트 한 줄로 되살아난다.
#
# kustomize 의 configMapGenerator 를 쓰지 않는 이유 — kustomize 는 kustomization.yaml 이
# 있는 디렉터리 밖의 파일을 읽지 못한다. 대시보드 JSON 을 k8s/ 아래로 복사하면
# 정본이 둘이 되므로, 스크립트로 만든다.
set -euo pipefail
LABS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="${NS:-monitoring}"
NAME="${NAME:-study-dashboards}"

ARGS=()
for f in "$LABS"/monitoring/dashboards/*.json; do
  ARGS+=(--from-file="$(basename "$f")=$f")
done
[ ${#ARGS[@]} -eq 0 ] && { echo "대시보드 JSON 이 없다: $LABS/monitoring/dashboards/" >&2; exit 1; }

kubectl -n "$NS" create configmap "$NAME" "${ARGS[@]}" \
  --dry-run=client -o yaml \
| kubectl label --local -f - grafana_dashboard=1 -o yaml \
| kubectl annotate --local -f - grafana_folder=스터디 -o yaml \
| kubectl apply -f -

echo "적용됨: $NS/$NAME"
kubectl -n "$NS" get cm "$NAME" -o jsonpath='  labels={.metadata.labels}{"\n"}  files={range .data.*}{"\n"}{end}' 2>/dev/null | head -2

#!/usr/bin/env bash
# M29 — 파이프라인의 한 단계씩을 로컬에서 그대로 돌린다.
#
# CI 서버에서 도는 것과 같은 명령을 쓰는 것이 중요하다.
# "내 컴퓨터에서는 되는데"의 절반은 CI 와 로컬이 다른 명령을 쓰기 때문에 생긴다.
#
# 사용법: scripts/ci.sh [단계...]      (인자가 없으면 전부)
#   scripts/ci.sh test build scan chart
set -euo pipefail
cd "$(dirname "$0")/.."          # course/labs
APP=apps/journal-api

# 이미지 태그는 커밋 해시다. latest 는 쓰지 않는다 (M26 의 정책이 거부한다).
# 커밋이 없는 상태에서도 돌 수 있게 폴백을 둔다.
SHA=$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)
IMAGE="journal-api:${SHA}"
STEPS=("$@")
[ ${#STEPS[@]} -eq 0 ] && STEPS=(typecheck build scan chart manifest policy)

has() { printf '%s\n' "${STEPS[@]}" | grep -qx "$1"; }
step() { printf '\n\033[1m▶ %s\033[0m\n' "$1"; }

if has typecheck; then
  step "1) 타입 검사 — 컨테이너 없이 가장 빠르게 깨진다"
  ( cd "$APP" && npm ci --silent && npm run typecheck )
fi

if has build; then
  step "2) 빌드 + 테스트 — 테스트가 실패하면 이미지가 만들어지지 않는다"
  docker build -t "$IMAGE" --build-arg "APP_VERSION=${SHA}" "$APP"
  echo "   이미지: $IMAGE"
fi

if has scan; then
  step "3) 취약점 스캔 — CRITICAL 이 있으면 실패"
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy:0.69.0 image --scanners vuln \
    --severity CRITICAL --exit-code 1 --quiet "$IMAGE" \
    || { echo "   CRITICAL 취약점이 있다. 베이스 이미지부터 확인한다 (M27 8절)"; exit 1; }
  echo "   CRITICAL 없음"
fi

if has chart; then
  step "4) 차트 검사 — 렌더링과 스키마"
  helm lint charts/journal
  helm template ci charts/journal -f charts/journal/values-prod.yaml >/dev/null
  echo "   helm template OK"
fi

if has manifest; then
  step "5) 매니페스트 검사 — 오버레이가 빌드되는가"
  kubectl kustomize k8s/journal >/dev/null
  kubectl kustomize k8s/overlays/dev >/dev/null
  kubectl kustomize k8s/overlays/prod >/dev/null
  echo "   kustomize build OK (base + 오버레이 2개)"
fi

if has policy; then
  step "6) 정책 검사 — 어드미션이 받아 주는가 (클러스터 필요)"
  if kubectl cluster-info >/dev/null 2>&1; then
    helm template ci charts/journal -f charts/journal/values-prod.yaml \
      | kubectl apply --dry-run=server -f - >/dev/null
    echo "   --dry-run=server OK"
  else
    echo "   (클러스터 없음 — 건너뜀)"
  fi
fi

printf '\n\033[1m전부 통과. 배포할 이미지: %s\033[0m\n' "$IMAGE"

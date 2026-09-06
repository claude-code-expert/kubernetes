#!/usr/bin/env bash
# 사용법: ./redeploy.sh order-api 0.0.2
set -euo pipefail

APP="${1:?앱 이름을 지정하세요 (order-api | gateway)}"
TAG="${2:?태그를 지정하세요 (예: 0.0.2)}"
IMAGE="obs/${APP}:${TAG}"

cd "$(dirname "$0")/${APP}"
./gradlew bootBuildImage --imageName="${IMAGE}"

kind load docker-image "${IMAGE}" --name obs

kubectl -n apps set image "deploy/${APP}" "${APP}=${IMAGE}"
kubectl -n apps rollout status "deploy/${APP}" --timeout=180s

echo "완료: ${IMAGE}"

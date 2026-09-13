#!/usr/bin/env bash
# 외부 예제 앱을 받아 온다.
#
# 복사해 두지 않는 이유: 원본이 따로 갱신되므로, 복사하면 어느 쪽이 정본인지
# 알 수 없게 된다. 대신 커밋을 고정해 받아 온다 — 문서에 적힌 화면과
# 받아 온 코드가 어긋나지 않게 하려면 SHA 고정이 필요하다.
#
# 두 앱의 역할은 다르다:
#   k8s-sample-boot  /hello 가 호스트명을 돌려준다. 어느 파드가 응답했는지
#                    눈으로 판정하는 최소 예제 (02 · 03장)
#   docker-sample    Dockerfile 4종으로 이미지 크기 감축을 재현 (03장)
#
# labs/apps/ 의 order-api · gateway 와 합치지 않는다. 그쪽은 커스텀 메트릭
# orders.* 를 갖고 있고 06장 PromQL 과 07장 대시보드가 그 이름에 의존한다.
set -euo pipefail

REPO="https://github.com/villainscode/kubernetes.git"
PIN="554717910ed75d8c957594622955f714f3ae4c85"
DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/labs/apps/external"

if [ -d "$DEST/.git" ]; then
  echo "이미 있음: $DEST"
  git -C "$DEST" fetch --quiet origin "$PIN" || true
else
  echo "받는 중: $REPO @ ${PIN:0:7}"
  git clone --quiet "$REPO" "$DEST"
fi

git -C "$DEST" checkout --quiet "$PIN"
echo "고정된 커밋: $(git -C "$DEST" rev-parse --short HEAD)"
echo
echo "받은 것:"
echo "  $DEST/docker-sample      Dockerfile.{naive,jre,multi,arg} · compose-{bad,good}.yaml"
echo "  $DEST/k8s-sample-boot    /hello · /actuator/prometheus"

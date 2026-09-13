#!/usr/bin/env bash
# M26 — 이미 배포된 리소스 중 정책 위반을 찾는다.
#
# 어드미션 정책은 새 요청에만 걸린다. 정책을 켜기 전에 배포된 것은 그대로 돌아간다.
# 서버 드라이런은 실제 어드미션을 통과시키되 저장하지 않으므로,
# "지금 다시 올린다면 거부당할 것"을 미리 알 수 있다.
#
# 사용법: policy-audit.sh [정책이름]   (기본값: no-latest-tag)
set -u
POLICY="${1:-no-latest-tag}"

# while 을 파이프 뒤에 두면 서브셸에서 돌아 변수가 밖으로 나오지 않는다.
# 결과를 변수에 모아서 마지막에 판정한다.
RESULT=$(
  kubectl get deploy,sts,ds -A \
    -o custom-columns=K:.kind,NS:.metadata.namespace,N:.metadata.name --no-headers |
  while read -r KIND NS NAME; do
    HIT=$(kubectl -n "$NS" get "$KIND" "$NAME" -o yaml |
          kubectl apply --dry-run=server -f - 2>&1 |
          grep -c "ValidatingAdmissionPolicy '$POLICY'")
    [ "$HIT" -gt 0 ] && echo "위반: $NS/$KIND/$NAME"
  done
)
if [ -z "$RESULT" ]; then
  echo "(위반 없음)"
else
  echo "$RESULT"
fi

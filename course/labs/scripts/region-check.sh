#!/usr/bin/env bash
# M32 — 리전 하나가 건강한지 판정한다. 확산 전에 반드시 통과해야 하는 관문.
#
# 사용법: region-check.sh <kube-context> <namespace> [기대 이미지]
#   region-check.sh kind-edge journal journal-api:v2
set -uo pipefail
CTX="${1:?컨텍스트}"; NS="${2:?네임스페이스}"; WANT="${3:-}"
FAIL=0
say() { printf '  %-28s %s\n' "$1" "$2"; }

# ① 모든 워크로드가 원하는 수만큼 준비됐는가
NOTREADY=$(kubectl --context "$CTX" -n "$NS" get deploy,sts -o json | python3 -c '
import json, sys
bad = []
for i in json.load(sys.stdin)["items"]:
    want = i["spec"].get("replicas", 1)
    got = i["status"].get("readyReplicas", 0)
    if got != want:
        bad.append("%s/%s %s/%s" % (i["kind"], i["metadata"]["name"], got, want))
print(";".join(bad))
') || { echo "  판정 스크립트 오류"; exit 2; }
[ -n "$NOTREADY" ] && { say "워크로드 준비" "실패: $NOTREADY"; FAIL=1; } || say "워크로드 준비" "OK"

# ② 재시작이 늘고 있지 않은가 (5회 이상이면 무언가 반복해서 죽는 것이다)
RESTARTS=$(kubectl --context "$CTX" -n "$NS" get po -o json |
  python3 -c '
import json,sys
m=0
for p in json.load(sys.stdin)["items"]:
    for c in p["status"].get("containerStatuses") or []:
        m=max(m,c.get("restartCount",0))
print(m)')
[ "$RESTARTS" -ge 5 ] && { say "최대 재시작 수" "실패: $RESTARTS"; FAIL=1; } || say "최대 재시작 수" "$RESTARTS"

# ②-b 진행 중인 롤아웃이 멈춰 있지 않은가
#     maxUnavailable: 0 이면 새 파드가 못 떠도 옛 파드가 남아 ①이 통과한다.
#     "원하는 개수만큼 준비됨"과 "롤아웃이 끝남"은 다른 조건이다.
for D in journal-api web-static; do
  if ! kubectl --context "$CTX" -n "$NS" rollout status "deploy/$D" --timeout=20s >/dev/null 2>&1; then
    say "롤아웃 $D" "실패: 20초 안에 끝나지 않음"; FAIL=1
  else
    say "롤아웃 $D" "완료"
  fi
done

# ③ 기대한 이미지가 돌고 있는가
if [ -n "$WANT" ]; then
  GOT=$(kubectl --context "$CTX" -n "$NS" get deploy journal-api \
        -o jsonpath='{.spec.template.spec.containers[0].image}')
  [ "$GOT" = "$WANT" ] && say "이미지" "$GOT" || { say "이미지" "실패: $GOT (기대 $WANT)"; FAIL=1; }
fi

# ④ 응답이 오는가 — 파드 안에서 자기 자신을 부른다
POD=$(kubectl --context "$CTX" -n "$NS" get po -l app=journal-api \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD" ]; then
  BODY=$(kubectl --context "$CTX" -n "$NS" exec "$POD" -- \
         wget -qO- --timeout=5 http://127.0.0.1:8080/readyz 2>/dev/null)
  case "$BODY" in
    *ready*) say "readyz" "$BODY" ;;
    *)       say "readyz" "실패: ${BODY:-응답 없음}"; FAIL=1 ;;
  esac
fi

if [ "$FAIL" -eq 0 ]; then
  echo "판정: 통과 — 다음 리전으로 확산해도 된다"
else
  echo "판정: 실패 — 확산하지 않는다"
fi
exit "$FAIL"

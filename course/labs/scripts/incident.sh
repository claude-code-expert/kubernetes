#!/usr/bin/env bash
# M38 캡스톤 — 장애를 심고 걷는다. 강사가 쓰는 스크립트다.
#
#   bash scripts/incident.sh inject 1     1번 장애를 심는다
#   bash scripts/incident.sh clear  1     걷는다
#   bash scripts/incident.sh clear  all   전부 걷는다
#
# 수강생에게는 번호도 알려 주지 않는다. "무언가 이상하다"에서 시작한다.
set -uo pipefail
NS=journal
ACTION="${1:-}"; ID="${2:-}"

inject_1() {  # 관측이 사라진다
  kubectl -n $NS patch servicemonitor journal-api --type=merge \
    -p '{"metadata":{"labels":{"release":"kps-typo"}}}'
  echo "1번 주입 완료"
}
clear_1() {
  kubectl -n $NS patch servicemonitor journal-api --type=merge \
    -p '{"metadata":{"labels":{"release":"kps"}}}'
  echo "1번 정리"
}

inject_2() {  # 이름 해석이 죽는다 (증상이 늦게 나타난다)
  kubectl -n $NS delete netpol allow-dns --ignore-not-found >/dev/null
  echo "2번 주입 완료"
}
clear_2() {
  kubectl apply -f "$(dirname "$0")/../k8s/netpol/10-allow.yaml" >/dev/null
  echo "2번 정리"
}

inject_3() {  # 느려진다. 그런데 지표는 한가하다
  kubectl -n $NS patch deploy journal-api --type=json \
    -p '[{"op":"add","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"50m"}]' >/dev/null
  echo "3번 주입 완료 (롤아웃 대기)"
  kubectl -n $NS rollout status deploy/journal-api --timeout=180s >/dev/null
}
clear_3() {
  kubectl -n $NS patch deploy journal-api --type=json \
    -p '[{"op":"remove","path":"/spec/template/spec/containers/0/resources/limits/cpu"}]' >/dev/null 2>&1
  kubectl -n $NS rollout status deploy/journal-api --timeout=180s >/dev/null
  echo "3번 정리"
}

case "$ACTION:$ID" in
  inject:1) inject_1 ;;
  inject:2) inject_2 ;;
  inject:3) inject_3 ;;
  clear:1)  clear_1 ;;
  clear:2)  clear_2 ;;
  clear:3)  clear_3 ;;
  clear:all) clear_1; clear_2; clear_3 ;;
  inject:all) inject_1; inject_2; inject_3 ;;
  *) echo "사용법: incident.sh {inject|clear} {1|2|3|all}"; exit 1 ;;
esac

#!/usr/bin/env bash
# course/labs/scripts/loadgen.sh
# M15 프로브 실습의 측정 도구. 클러스터 안에서 서비스에 직접 요청을 보내며
# 응답 코드를 센다.
#
#   bash course/labs/scripts/loadgen.sh start     부하 시작 (curlbox 가 없으면 만든다)
#   bash course/labs/scripts/loadgen.sh report    지금까지의 코드 분포
#   bash course/labs/scripts/loadgen.sh reset     카운터만 0으로
#   bash course/labs/scripts/loadgen.sh stop      부하 종료 (curlbox 는 남는다)
#   bash course/labs/scripts/loadgen.sh clean     부하 종료 + curlbox 삭제
#
# **멈추는 방법은 `stop` 이다.** 이 스크립트는 백그라운드 루프를 파드 안에 띄우므로
# 터미널을 닫아도 계속 돈다. 실습이 끝나면 반드시 `stop` 또는 `clean` 을 실행한다.
#
# 왜 인그레스가 아니라 서비스에 직접 때리는가 —
# 인그레스 컨트롤러는 업스트림이 사라지면 자체적으로 다시 시도한다. 그래서 호스트에서
# `localhost:18080` 으로 재면 파드가 실제로 떨어뜨린 요청이 가려져 1~3건으로 나온다.
# 이 모듈이 재려는 것은 컨트롤러의 재시도 성능이 아니라 **엔드포인트에서 빠지는 일과
# 프로세스가 죽는 일의 시간 차**다. 그래서 서비스 → 파드 한 구간만 남기고 잰다.
#
# 왜 요청 사이에 sleep 을 넣는가 —
# 넣지 않고 동시 8줄로 때리면 curlbox 한 파드가 소켓을 다 써 버려서, 롤아웃을 하지
# 않아도 37~93%가 실패한다. 측정 도구가 측정 대상보다 먼저 무너지는 상태다.
# 동시 4줄 + 0.02초(약 158 req/s)에서는 롤아웃 없이 20초를 돌려도 실패가 0이다.
# 부하 자체가 목적인 측정은 M17·M37 에서 k6 로 한다.
set -uo pipefail

NS="${NS:-journal}"
SVC="${SVC:-journal-api}"
PORT="${PORT:-8080}"
PATHNAME="${PATHNAME:-/api/entries}"
PARALLEL="${PARALLEL:-4}"
INTERVAL="${INTERVAL:-0.02}"
POD=curlbox

k() { kubectl -n "$NS" "$@"; }

ensure_pod() {
  if ! k get pod "$POD" >/dev/null 2>&1; then
    echo "curlbox 가 없다. 만든다."
    # M24 에서 journal 네임스페이스에 restricted 를 걸었다.
    # kubectl run 이 만드는 기본 파드는 거부되므로 securityContext 를 갖춘 매니페스트를 쓴다.
    # 이미지도 curl 이 들어 있는 것으로 고정한다 — 비루트라 apk add 를 할 수 없다.
    cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: $POD
  namespace: $NS
  labels:
    # M25 의 네트워크 정책이 이 라벨로 부하 생성기의 경로를 연다.
    # 라벨이 없으면 default-deny 에 걸려 전부 000 이 된다.
    role: loadgen
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    seccompProfile: {type: RuntimeDefault}
  containers:
    - name: curlbox
      image: curlimages/curl:8.19.0
      command: ["sleep", "infinity"]
      securityContext:
        allowPrivilegeEscalation: false
        capabilities: {drop: ["ALL"]}
      resources:
        requests: {cpu: 20m, memory: 32Mi}
        limits: {memory: 64Mi}
YAML
    k wait --for=condition=Ready "pod/$POD" --timeout=90s >/dev/null
  fi
}

case "${1:-}" in
  start)
    ensure_pod
    k exec "$POD" -- sh -c "
      rm -f /tmp/codes.*.txt
      touch /tmp/run
      i=1
      while [ \$i -le $PARALLEL ]; do
        ( while [ -f /tmp/run ]; do
            curl -s -o /dev/null -w '%{http_code}\n' --max-time 2 \
              http://$SVC:$PORT$PATHNAME >> /tmp/codes.\$i.txt 2>/dev/null
            sleep $INTERVAL
          done ) &
        i=\$((i+1))
      done
    " >/dev/null 2>&1 &
    sleep 3
    echo "부하 시작 — $SVC:$PORT$PATHNAME 에 동시 $PARALLEL 줄, 요청 간격 ${INTERVAL}초"
    echo "멈추려면: bash \$0 stop"
    ;;
  report)
    echo "요청 수 / 응답 코드 분포:"
    k exec "$POD" -- sh -c 'cat /tmp/codes.*.txt 2>/dev/null | wc -l; cat /tmp/codes.*.txt 2>/dev/null | sort | uniq -c | sort -rn'
    ;;
  reset)
    k exec "$POD" -- sh -c 'for f in /tmp/codes.*.txt; do : > "$f"; done' 2>/dev/null
    echo "카운터를 0으로 되돌렸다. 부하는 계속 돈다."
    ;;
  stop)
    k exec "$POD" -- sh -c 'rm -f /tmp/run' 2>/dev/null
    sleep 2
    echo "부하 종료. 마지막 집계:"
    k exec "$POD" -- sh -c 'cat /tmp/codes.*.txt 2>/dev/null | wc -l; cat /tmp/codes.*.txt 2>/dev/null | sort | uniq -c | sort -rn'
    ;;
  clean)
    k exec "$POD" -- sh -c 'rm -f /tmp/run' 2>/dev/null
    k delete pod "$POD" --ignore-not-found
    ;;
  *)
    sed -n '3,12p' "$0"
    exit 1
    ;;
esac

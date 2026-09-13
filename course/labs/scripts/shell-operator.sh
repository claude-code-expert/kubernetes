#!/usr/bin/env bash
# M33 — 조정 루프를 셸로 흉내 낸다.
#
# 오퍼레이터가 하는 일은 결국 이 세 줄이다:
#   ① 원하는 상태를 읽는다 (spec)
#   ② 실제 상태와 비교한다
#   ③ 차이를 없애고 status 를 갱신한다
#
# 진짜 컨트롤러와 다른 점은 성능과 정확성이지 개념이 아니다.
# (watch 대신 폴링, 캐시 없음, 동시성 제어 없음, 재시도 백오프 없음)
set -uo pipefail
NS="${1:-m33}"
INTERVAL="${2:-5}"
echo "조정 루프 시작 — 네임스페이스 $NS, 간격 ${INTERVAL}초 (Ctrl+C 로 종료)"

while true; do
  for NAME in $(kubectl -n "$NS" get journalsites -o jsonpath='{.items[*].metadata.name}'); do
    # ① 원하는 상태
    SPEC=$(kubectl -n "$NS" get js "$NAME" -o json)
    IMAGE=$(echo "$SPEC" | python3 -c 'import json,sys; print(json.load(sys.stdin)["spec"]["image"])')
    WANT=$(echo "$SPEC"  | python3 -c 'import json,sys; print(json.load(sys.stdin)["spec"].get("replicas",2))')
    GEN=$(echo "$SPEC"   | python3 -c 'import json,sys; print(json.load(sys.stdin)["metadata"]["generation"])')
    LOG=$(echo "$SPEC"   | python3 -c 'import json,sys; print(json.load(sys.stdin)["spec"].get("logLevel","info"))')

    # ② 실제 상태를 원하는 상태로 만든다 (여기서는 디플로이먼트 하나)
    #    ownerReferences 를 넣는 것이 핵심이다 — JournalSite 를 지우면 이것도 따라 지워진다.
    OWNER_UID=$(echo "$SPEC" | python3 -c 'import json,sys; print(json.load(sys.stdin)["metadata"]["uid"])')
    cat <<YAML | kubectl -n "$NS" apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${NAME}-api
  labels: {app: ${NAME}, managed-by: shell-operator}
  ownerReferences:
    - apiVersion: study.example.com/v1alpha1
      kind: JournalSite
      name: ${NAME}
      uid: ${OWNER_UID}
      controller: true
      blockOwnerDeletion: true
spec:
  replicas: ${WANT}
  selector: {matchLabels: {app: ${NAME}}}
  template:
    metadata: {labels: {app: ${NAME}}}
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile: {type: RuntimeDefault}
      automountServiceAccountToken: false
      containers:
        - name: api
          image: ${IMAGE}
          imagePullPolicy: IfNotPresent
          env:
            - {name: LOG_LEVEL, value: "${LOG}"}
          ports: [{name: http, containerPort: 8080}]
          resources:
            requests: {cpu: 20m, memory: 48Mi}
            limits: {memory: 128Mi}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: ["ALL"]}
          readinessProbe:
            httpGet: {path: /readyz, port: http}
            periodSeconds: 2
YAML

    # ③ status 를 갱신한다. --subresource=status 가 없으면 spec 을 덮어쓴다.
    READY=$(kubectl -n "$NS" get deploy "${NAME}-api" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    READY=${READY:-0}
    if [ "$READY" = "$WANT" ]; then PHASE=Ready; else PHASE=Progressing; fi
    kubectl -n "$NS" patch js "$NAME" --subresource=status --type=merge -p \
      "{\"status\":{\"readyReplicas\":${READY},\"phase\":\"${PHASE}\",\"observedGeneration\":${GEN}}}" >/dev/null
    printf '%s  %-10s want=%s ready=%s phase=%s\n' "$(date +%H:%M:%S)" "$NAME" "$WANT" "$READY" "$PHASE"
  done
  sleep "$INTERVAL"
done

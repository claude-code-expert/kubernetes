#!/usr/bin/env bash
# course/labs/scripts/make-dev-kubeconfig.sh
# journal 네임스페이스만 다룰 수 있는 개발자용 kubeconfig 를 만든다 (M23).
#
#   bash course/labs/scripts/make-dev-kubeconfig.sh          # /tmp/dev.kubeconfig 생성
#   KUBECONFIG=/tmp/dev.kubeconfig kubectl get pods
#
# 검색하면 나오는 방법은 이렇다:
#   kubectl -n journal get sa dev -o jsonpath='{.secrets[0].name}'
# 1.24 부터 서비스어카운트에 토큰 시크릿이 자동 생성되지 않으므로 **빈 값이 나온다.**
# 지금은 `kubectl create token` 으로 수명이 정해진 토큰을 받는다.
set -euo pipefail
NS="${NS:-journal}"
SA="${SA:-dev}"
OUT="${OUT:-/tmp/dev.kubeconfig}"
TTL="${TTL:-1h}"
CTX=$(kubectl config current-context)
CLUSTER=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$CTX\")].context.cluster}")
SERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$CLUSTER\")].cluster.server}")
CA=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"$CLUSTER\")].cluster.certificate-authority-data}")

TOKEN=$(kubectl -n "$NS" create token "$SA" --duration="$TTL")

cat > "$OUT" <<KEOF
apiVersion: v1
kind: Config
clusters:
  - name: $CLUSTER
    cluster:
      server: $SERVER
      certificate-authority-data: $CA
users:
  - name: $SA
    user:
      token: $TOKEN
contexts:
  - name: $SA@$CLUSTER
    context:
      cluster: $CLUSTER
      user: $SA
      namespace: $NS
current-context: $SA@$CLUSTER
KEOF
chmod 600 "$OUT"
echo "만듦: $OUT (유효기간 $TTL)"
KUBECONFIG="$OUT" kubectl auth whoami 2>/dev/null || echo "  (auth whoami 미지원)"

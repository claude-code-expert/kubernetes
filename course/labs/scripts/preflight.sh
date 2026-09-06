#!/usr/bin/env bash
# course/labs/scripts/preflight.sh
# 실습을 시작하기 전에 환경이 갖춰졌는지 9개 영역을 점검한다.
# 실패한 항목이 있으면 M01 문서의 해당 절로 돌아간다.
set -uo pipefail

CLUSTER="${CLUSTER:-study}"
OK=0; NG=0

pass() { printf '  [ OK ] %s\n' "$1"; OK=$((OK+1)); }
fail() { printf '  [FAIL] %s\n' "$1"; NG=$((NG+1)); }

echo "== 1. 컨테이너 런타임"
if docker info >/dev/null 2>&1; then
  pass "docker 데몬 응답 (Server $(docker version --format '{{.Server.Version}}'))"
else
  fail "docker 데몬이 응답하지 않는다. Docker Desktop / OrbStack / Colima를 실행하라"
fi

echo "== 2. 도구 설치"
for t in kind kubectl helm k6; do
  if command -v "$t" >/dev/null 2>&1; then pass "$t 설치됨 ($(command -v $t))"; else fail "$t 없음 — brew install $t"; fi
done
JV=$(java -version 2>&1 | head -1 | grep -o '"[0-9]*' | tr -d '"')
if [ "${JV:-0}" = "21" ]; then
  pass "JDK 21 ($(java -version 2>&1 | head -1))"
else
  fail "JDK 21 없음 (java -version: ${JV:-없음}) — brew install openjdk@21 후 PATH에 /opt/homebrew/opt/openjdk@21/bin 추가"
fi

echo "== 3. kubectl 버전 스큐"
CV=$(kubectl version -o json 2>/dev/null | grep -o '"gitVersion": *"v[0-9.]*"' | head -1 | grep -o 'v[0-9.]*')
SV=$(kubectl version -o json 2>/dev/null | grep -o '"gitVersion": *"v[0-9.]*"' | tail -1 | grep -o 'v[0-9.]*')
if [ -n "${SV:-}" ] && [ "${CV%.*}" = "${SV%.*}" ]; then
  pass "client $CV / server $SV — 마이너 버전 일치"
elif [ -n "${SV:-}" ]; then
  fail "client $CV / server $SV — 마이너 차이가 나면 경고가 뜬다. kubectl을 서버에 맞춰라"
else
  fail "서버 버전을 못 읽었다. 클러스터가 없거나 컨텍스트가 잘못됐다"
fi

echo "== 4. 클러스터 존재"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  pass "kind 클러스터 '$CLUSTER' 존재"
else
  fail "kind 클러스터 '$CLUSTER' 없음 — kind create cluster --config infra/kind-cluster.yaml"
fi

echo "== 5. 컨텍스트"
CTX=$(kubectl config current-context 2>/dev/null || echo "none")
if [ "$CTX" = "kind-$CLUSTER" ]; then
  pass "현재 컨텍스트 $CTX"
else
  fail "현재 컨텍스트가 $CTX 다. kubectl config use-context kind-$CLUSTER"
fi

echo "== 6. 노드 상태"
READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready ')
TOTAL=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${READY:-0}" -ge 3 ]; then
  pass "노드 $READY/$TOTAL Ready"
else
  fail "Ready 노드가 ${READY:-0}개다 (3개 필요). kubectl get nodes 로 확인하라"
fi

echo "== 7. 컨트롤 플레인"
if kubectl get --raw='/readyz' 2>/dev/null | grep -q ok; then
  pass "apiserver readyz ok"
else
  fail "apiserver readyz 실패"
fi

echo "== 8. metrics-server"
if kubectl top nodes --no-headers >/dev/null 2>&1; then
  pass "kubectl top nodes 응답 — metrics-server 동작"
else
  fail "kubectl top nodes 실패 — metrics-server 미설치 또는 --kubelet-insecure-tls 누락 (M01 1.5절 7단계)"
fi

echo "== 9. 런타임 자원"
MEM=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)
MEMG=$(( MEM / 1024 / 1024 / 1024 ))
if [ "$MEMG" -ge 6 ]; then
  pass "런타임 메모리 ${MEMG}GiB"
else
  fail "런타임 메모리 ${MEMG}GiB — 6GiB 이상 권장. Part 4 관측 스택이 뜨지 않는다"
fi

echo
echo "통과 $OK · 실패 $NG"
[ "$NG" -eq 0 ] || exit 1

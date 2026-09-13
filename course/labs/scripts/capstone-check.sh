#!/usr/bin/env bash
# M38 — 통주 점검. 서른일곱 개 모듈의 산출물이 클러스터에 실제로 있는지 확인한다.
#
#   bash course/labs/scripts/capstone-check.sh          전부
#   bash course/labs/scripts/capstone-check.sh part3     한 파트만
#
# 이 스크립트는 **문서가 맞는지**를 검사한다. 실패한 항목은 그 모듈로 돌아가라는 뜻이다.
# 종료 코드: 0 전부 통과 / 1 실패 항목 있음
set -uo pipefail
FILTER="${1:-all}"
PASS=0; FAIL=0
CWD="$(cd "$(dirname "$0")/../../.." && pwd)"   # 저장소 루트

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
no()   { printf '  \033[31m✗\033[0m %s  \033[31m(%s)\033[0m\n' "$1" "$2"; FAIL=$((FAIL+1)); }
part() { case "$FILTER" in all|"$1") return 0;; *) return 1;; esac; }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# 조건 검사: check "설명" "기대값" 명령...
check() {
  local desc="$1" want="$2"; shift 2
  local got; got=$("$@" 2>/dev/null | tr -d '\n')
  if [ "$got" = "$want" ]; then ok "$desc"; else no "$desc" "기대 '$want' 실제 '$got'"; fi
}
# 0 보다 큰 수인지
check_gt0() {
  local desc="$1"; shift
  local got; got=$("$@" 2>/dev/null | tr -d '\n ')
  if [ -n "$got" ] && [ "$got" -gt 0 ] 2>/dev/null; then ok "$desc ($got)"; else no "$desc" "실제 '$got'"; fi
}
# 파일 존재
check_file() {
  local desc="$1" path="$2"
  if [ -e "$CWD/$path" ]; then ok "$desc"; else no "$desc" "없음: $path"; fi
}

if part part1; then
head_ "Part 1 — 도커 (M01~M07)"
check_file "M01 kind 클러스터 정의"        course/labs/infra/kind-cluster.yaml
check_file "M01 복구 스크립트"             course/labs/scripts/rebuild.sh
check_file "M04 저널 앱 소스"              course/labs/apps/journal-api/src/server.ts
check_file "M07 멀티스테이지 Dockerfile"   course/labs/apps/journal-api/Dockerfile
check "M01 노드 3개" "3" \
  bash -c "kubectl get nodes --no-headers | wc -l | tr -d ' '"
check "M07 비루트 이미지" "1" \
  bash -c "grep -c '^USER 1000' '$CWD/course/labs/apps/journal-api/Dockerfile'"
fi

if part part2; then
head_ "Part 2 — 쿠버네티스 기초 (M08~M14)"
check "M10 저널 API 가 떠 있다" "3" \
  bash -c "kubectl -n journal get deploy journal-api -o jsonpath='{.status.readyReplicas}'"
check "M11 헤드리스 레디스 서비스" "None" \
  bash -c "kubectl -n journal get svc redis -o jsonpath='{.spec.clusterIP}'"
check_gt0 "M12 인그레스가 있다" \
  bash -c "kubectl -n journal get ingress --no-headers | wc -l | tr -d ' '"
check "M13 컨피그맵" "journal-config" \
  bash -c "kubectl -n journal get cm journal-config -o jsonpath='{.metadata.name}'"
check_file "M14 헬름 차트"                 course/labs/charts/journal/Chart.yaml
fi

if part part3; then
head_ "Part 3 — 안정성 (M15~M18)"
check "M15 프로브 3종" "3" \
  bash -c "kubectl -n journal get deploy journal-api -o json | grep -c 'Probe\"'"
check "M15 preStop" "sleep 10" \
  bash -c "kubectl -n journal get deploy journal-api -o jsonpath='{.spec.template.spec.containers[0].lifecycle.preStop.exec.command[2]}'"
check "M16 cpu limit 없음 (의도된 결정)" "0" \
  bash -c "kubectl -n journal get deploy journal-api -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' | wc -c | tr -d ' '"
check "M16 토폴로지 분산" "Honor" \
  bash -c "kubectl -n journal get deploy journal-api -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].nodeTaintsPolicy}'"
check_gt0 "M17 HPA" \
  bash -c "kubectl -n journal get hpa --no-headers | wc -l | tr -d ' '"
check_gt0 "M16 PDB" \
  bash -c "kubectl -n journal get pdb --no-headers | wc -l | tr -d ' '"
check "M18 레디스 볼륨" "Bound" \
  bash -c "kubectl -n journal get pvc -l app=redis -o jsonpath='{.items[0].status.phase}'"
fi

if part part4; then
head_ "Part 4 — 관측 (M19~M22)"
check_gt0 "M19 metrics-server" \
  bash -c "kubectl -n kube-system get deploy metrics-server -o jsonpath='{.status.readyReplicas}'"
check_gt0 "M20 ServiceMonitor" \
  bash -c "kubectl -n journal get servicemonitor --no-headers | wc -l | tr -d ' '"
check_gt0 "M21 PrometheusRule" \
  bash -c "kubectl -n monitoring get prometheusrule --no-headers | wc -l | tr -d ' '"
check_gt0 "M22 로그 수집기(Alloy)" \
  bash -c "kubectl -n logging get ds -o jsonpath='{.items[0].status.numberReady}'"
check_gt0 "M22 Loki" \
  bash -c "kubectl -n logging get sts loki -o jsonpath='{.status.readyReplicas}'"
fi

if part part5; then
head_ "Part 5 — 보안 (M23~M27)"
check "M24 PSA restricted" "restricted" \
  bash -c "kubectl get ns journal -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'"
check "M24 비루트 실행" "true" \
  bash -c "kubectl -n journal get deploy journal-api -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}'"
check_gt0 "M25 네트워크 정책" \
  bash -c "kubectl -n journal get netpol --no-headers | wc -l | tr -d ' '"
check_gt0 "M26 어드미션 정책" \
  bash -c "kubectl get validatingadmissionpolicy --no-headers | grep -c 'no-latest-tag\|allowed-registries'"
check_file "M26 정책 감사 스크립트"        course/labs/scripts/policy-audit.sh
check "M27 감사 로깅" "1" \
  bash -c "docker exec study-control-plane grep -c audit-policy-file /etc/kubernetes/manifests/kube-apiserver.yaml"
check_file "M27 CIS 진단 잡"               course/labs/k8s/audit/kube-bench-job.yaml
fi

if part part6; then
head_ "Part 6 — 배포 자동화 (M28~M32)"
check_file "M28 차트 값 스키마"            course/labs/charts/journal/values.schema.json
check_file "M28 kustomize 오버레이"        course/labs/k8s/overlays/prod/kustomization.yaml
check_file "M29 CI 워크플로"               .github/workflows/ci.yaml
check_file "M29 로컬 파이프라인"           course/labs/scripts/ci.sh
check "M29 앱 단위 테스트" "4" \
  bash -c "cd '$CWD/course/labs/apps/journal-api' && npm test 2>&1 | grep -oE 'pass [0-9]+' | grep -oE '[0-9]+'"
check_gt0 "M30 Argo Rollouts" \
  bash -c "kubectl -n argo-rollouts get deploy argo-rollouts -o jsonpath='{.status.readyReplicas}'"
check_gt0 "M31 Argo CD" \
  bash -c "kubectl -n argocd get deploy argocd-server -o jsonpath='{.status.readyReplicas}'"
check_file "M32 롤아웃 러너북"             course/labs/k8s/multi/RUNBOOK.md
check_file "M32 리전 점검 스크립트"        course/labs/scripts/region-check.sh
fi

if part part7; then
head_ "Part 7 — 확장 (M33~M35)"
check_file "M33 손으로 쓴 CRD"             course/labs/k8s/crd/00-journalsite-crd.yaml
check_file "M33 오퍼레이터 조정 함수"      course/labs/operator/journalsite/internal/controller/journalsite_controller.go
check_file "M34 셀렉터 없는 서비스"        course/labs/k8s/external/10-selectorless.yaml
check_file "M35 인덱스 잡"                 course/labs/k8s/batch/10-indexed-job.yaml
check "M35 DRA API" "5" \
  bash -c "kubectl api-resources --api-group=resource.k8s.io --no-headers | wc -l | tr -d ' '"
fi

if part part8; then
head_ "Part 8 — 검증 (M36~M38)"
check_gt0 "M36 Chaos Mesh" \
  bash -c "kubectl -n chaos-mesh get deploy chaos-controller-manager -o jsonpath='{.status.readyReplicas}'"
check_file "M36 게임 데이 시트"            course/labs/chaos/GAMEDAY.md
check_file "M36 퍼즈 스크립트"             course/labs/scripts/fuzz-api.sh
check_file "M37 용량 시나리오"             course/labs/scripts/k6-capacity.js
check_file "M38 A/B 실험"                  course/labs/k8s/experiment/10-ab.yaml
fi

head_ "결과"
printf '  통과 %d · 실패 %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && { echo "  전부 통과 — 통주 완료"; exit 0; }
echo "  실패한 항목의 모듈로 돌아간다"
exit 1

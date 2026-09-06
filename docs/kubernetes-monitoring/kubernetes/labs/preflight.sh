#!/usr/bin/env bash
# preflight.sh — 관측성 실습 사전 점검 (2026-08 기준)
set -u

report() {
  # $1=도구명  $2=권장버전  $3=탐지된 버전
  if [ -z "$3" ]; then
    printf '%-10s %-24s %s\n' "$1" "MISSING" "설치 필요 (권장 $2)"
    return 1
  fi
  printf '%-10s %-24s %s\n' "$1" "$3" "(권장 $2)"
  return 0
}

fail=0
echo "=== 도구 버전 ==="
report docker  "24.0+"   "$(docker version --format '{{.Server.Version}}' 2>/dev/null)" || fail=1
report kubectl "v1.36.x" "$(kubectl version --client -o yaml 2>/dev/null | awk '/gitVersion/{print $2; exit}')" || fail=1
report kind    "v0.32.0" "$(kind version 2>/dev/null | awk '{print $2}')" || fail=1
report helm    "v3.16+"  "$(helm version --short 2>/dev/null)" || fail=1
report java    "21"      "$(java -version 2>&1 | awk -F'"' '/version/{print $2; exit}')" || fail=1

echo
echo "=== 도커 자원 ==="
dk="$(docker info --format '{{.NCPU}} {{.MemTotal}}' 2>/dev/null || true)"
if [ -n "$dk" ]; then
  echo "$dk" | awk '{printf "CPU %s코어 / MEM %.1f GiB\n", $1, $2/1073741824}'
else
  echo "도커 데몬에 접속할 수 없습니다"
  fail=1
fi

echo
echo "=== cgroup 버전 (cgroup2fs 여야 정상) ==="
if [ "$(uname -s)" = "Linux" ]; then
  stat -fc %T /sys/fs/cgroup/
else
  docker run --rm alpine stat -fc %T /sys/fs/cgroup/ 2>/dev/null || echo "확인 불가"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "결과: 통과 — 01단계로 진행하세요"
else
  echo "결과: 미충족 항목 있음 — 06절 설치 절차를 확인하세요"
fi
exit "$fail"

#!/usr/bin/env bash
# M31 — 로컬 작업본을 클러스터 안 깃 서버로 밀어 넣는다.
#
# 실제 GitOps 에서는 `git push` 한 번이면 된다. 여기서는 깃 서버가 읽기 전용(git daemon)이라
# 베어 저장소를 다시 만들어 복사한다. 절차의 본질(커밋이 배포다)은 같다.
set -euo pipefail
WORK="${1:-}"
[ -z "$WORK" ] && { echo "사용법: gitops-push.sh <작업 저장소 경로>"; exit 1; }

TMP=$(mktemp -d)
git clone -q --bare "$WORK" "$TMP/repo.git"
POD=$(kubectl -n gitops get po -l app=gitserver -o jsonpath='{.items[0].metadata.name}')
kubectl -n gitops exec "$POD" -- sh -c 'rm -rf /repos/repo.git'
kubectl cp "$TMP/repo.git" "gitops/$POD:/repos/repo.git"
rm -rf "$TMP"

# Argo CD 는 기본 3분마다 폴링한다. 실습에서는 기다리지 않고 즉시 확인시킨다.
# M31 은 journal 하나, M32 는 journal-edge·journal-primary 둘이다. 있는 것을 전부 새로고침한다.
# 첫 푸시(M31 31.3 2단계) 때는 애플리케이션이 아직 없으므로 건너뛴다.
APPS=$(kubectl -n argocd get applications -o name 2>/dev/null || true)
if [ -n "$APPS" ]; then
  kubectl -n argocd annotate $APPS argocd.argoproj.io/refresh=hard --overwrite >/dev/null
  echo "푸시 완료. 새로고침: $(echo $APPS | sed 's|application.argoproj.io/||g')"
else
  echo "푸시 완료. 애플리케이션은 아직 없다 — 만들고 나면 푸시할 때마다 새로고침한다."
fi

# M31 — GitOps 실습 자산

- `00-gitserver.yaml` : 클러스터 안의 깃 서버 (git:// 프로토콜)
- `10-application.yaml` : Argo CD Application
- `repo-template/` : 깃 저장소에 넣을 내용의 스냅숏
- `../../apps/gitserver/Dockerfile` : git daemon 이미지

저장소를 만들고 밀어 넣는 순서는 `scripts/gitops-push.sh` 를 쓴다.

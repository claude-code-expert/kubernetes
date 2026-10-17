# 7주차 예제

로컬 kind 클러스터 하나로 따라 할 수 있는 것(01·02·05·06)과, 추가 컨트롤러가 있어야 하는 것(03·04·ci)으로 나뉩니다.
아래 출력은 **kind v0.33.0 · Kubernetes v1.37** 에서 발표 전에 직접 돌린 결과입니다.

| 폴더 | 장표 | 필요한 것 |
| --- | --- | --- |
| `01-rolling/` | 3부 끊기지 않게 하려면, 데모 | kind |
| `02-blue-green/` | 3부 블루/그린 | kind |
| `03-canary-gateway/` | 3부 카나리는 어디서 나누나 | Gateway API CRD + 구현체 |
| `04-argo-rollouts/` | 3부 Argo Rollouts로 베이스라인 비교 | Argo Rollouts + Prometheus + 트래픽 라우터 |
| `05-gitops/` | 1부 CI는 커밋까지만(`overlays/prod`), 3부 보충 7장 리전(`overlays/canary-kr`, `overlays/eu`) | `kubectl kustomize` 만으로 렌더링 확인 |
| `06-book-pitfalls/` | 1부 6.4 예제의 함정, 5.9 실습의 함정 | kind |
| `ci/release.yaml` | 1부 CI는 커밋까지만 | GitHub Actions (참고용) |

## 준비

```bash
kind create cluster --name week07
kubectl apply -f 01-rolling/
kubectl rollout status deploy/web
```

## 데모 1 · 롤링 업데이트 중 요청이 끊기는가

```bash
# 0.2초마다 요청을 보내는 파드
kubectl run poller --image=curlimages/curl --command -- \
  sh -c 'while true; do curl -s -o /dev/null -m 2 -w "%{http_code}\n" http://web; sleep .2; done'

kubectl set image deploy/web web=nginx:1.27
kubectl get rs -l app=web -w          # 다른 터미널에서
kubectl logs poller | sort | uniq -c
```

```
NAME             DESIRED   CURRENT   READY   AGE
web-86747d597    3         3         3       25s
web-868866ff7b   0         0         0       42s      ← 옛 RS 는 0 으로 남는다
 160 200                                              ← 교체 중 요청 160회 전부 200
```

`preStop` 을 지우고 세 번 더 교체해도 결과는 같았습니다.

```bash
kubectl patch deploy web --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/containers/0/lifecycle"}]'
```

```
 343 200
```

kind 는 노드가 하나라 엔드포인트 제거가 거의 즉시 반영됩니다. 장표에서 본 문제(엔드포인트 제거와 SIGTERM이 동시에 시작)는
외부 로드밸런서나 인그레스 컨트롤러처럼 **네트워크 쪽 반영이 느린 환경**에서 드러납니다.

## 데모 2 · 깨진 이미지는 멈추기만 한다

```bash
kubectl set image deploy/web web=nginx:no-such-tag
kubectl rollout status deploy/web --timeout=90s; echo "exit=$?"
```

```
Waiting for deployment "web" rollout to finish: 1 out of 3 new replicas have been updated...
error: deployment "web" exceeded its progress deadline
exit=1

web-564d98c4cd-7l45h 0/1 ErrImagePull
web-f84b8bdbf-mzxvs  1/1 Running      ← maxUnavailable 0 이라 옛 파드 3개가 그대로
web-f84b8bdbf-rhcjt  1/1 Running
web-f84b8bdbf-s2zwl  1/1 Running

Available=True    MinimumReplicasAvailable
Progressing=False ProgressDeadlineExceeded   ← 조건만 바뀌고 되돌리지 않는다
  20 200                                      ← 서비스는 계속 된다
```

## 데모 3 · undo 는 새 리비전을 만든다

```bash
kubectl rollout history deploy/web
kubectl rollout undo deploy/web
kubectl rollout history deploy/web
```

```
전: 1 2 5 6 (7 = 깨진 이미지)      후: 2 5 7 8      ← 직전 리비전(6)이 사라지고 같은 내용이 새 번호(8)로
```

번호는 그전에 몇 번 배포했는지에 따라 다릅니다.

## 데모 4 · 블루/그린 전환과 롤백

```bash
kubectl apply -f 02-blue-green/
kubectl exec poller -- curl -sI http://web-bg | grep -i server
kubectl patch svc web-bg -p '{"spec":{"selector":{"app":"web-bg","slot":"green"}}}'
```

```
전환 전: Server: nginx/1.26.3
전환 후: Server: nginx/1.27.5
롤백 후: Server: nginx/1.26.3      ← 셀렉터를 되돌리는 것만으로
```

## 교재 6.4 예제의 함정 (`06-book-pitfalls/`)

```bash
kubectl apply --dry-run=server -f 06-book-pitfalls/v1-as-in-book.yaml
```
```
metadata.labels: Invalid value: "release number": name part must consist of alphanumeric characters, '-', '_' or '.' ...
```

```bash
kubectl apply -f 06-book-pitfalls/v1-fixed.yaml           # 공백 키만 고침 → 생성됨
kubectl apply -f 06-book-pitfalls/v2-bump-template.yaml   # template 의 ver 만 1.5.9
```
```
spec.template.metadata.labels: Invalid value: {...,"ver":"1.5.9"}: `selector` does not match template `labels`
```
```bash
kubectl apply -f 06-book-pitfalls/v2-bump-both.yaml       # 셀렉터도 1.5.9
```
```
spec.selector: Invalid value: {...,"ver":"1.5.9"}: field is immutable
```

→ 셀렉터에 버전을 넣으면 **버전을 올릴 수 없는 디플로이먼트**가 됩니다.

```bash
kubectl label deploy gb-web-deploy appver=1.7.0 --overwrite
kubectl get rs -l app=gb-web --no-headers | wc -l        # 1 — metadata 레이블 변경은 롤아웃을 일으키지 않는다
```

헬름 훅 어노테이션을 같은 키로 세 번 쓰면 (`helm-hook-duplicate-keys.yaml`):

```
PyYAML: {'helm.sh/hook': 'pre-rollback', 'helm.sh/hook-delete-policy': 'hook-succeeded'}
```

마지막 값만 남습니다. 헬름 문서의 형식은 `"helm.sh/hook": pre-upgrade,pre-delete,pre-rollback` 입니다.

## 교재 5.9 실습의 토큰 조회

```bash
kubectl create sa drone
kubectl get sa drone -o jsonpath='{.secrets}'     # 빈 값 — v1.24 부터 토큰 시크릿이 자동 생성되지 않는다
kubectl create token drone --duration=1h          # 짧은 수명 토큰
```

## 정리

```bash
kind delete cluster --name week07
```

---

## Argo Rollouts, Argo CD 실습 (`07`, `08`, `09`)

kind v0.33.0 · Kubernetes v1.37 · Argo Rollouts v1.10.0 · Argo CD v3.5.3 에서 확인했습니다.

### 설치

```bash
kubectl create ns argo-rollouts
kubectl apply --server-side -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
brew install argoproj/tap/kubectl-argo-rollouts

kubectl create ns argocd
kubectl apply --server-side -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

`--server-side` 없이 적용하면 CRD 두 개가 거부됩니다. 일반 apply가 적용 내용을 어노테이션에 저장하는데 CRD가 커서 한도를 넘습니다.

```
CustomResourceDefinition.apiextensions.k8s.io "rollouts.argoproj.io" is invalid:
metadata.annotations: Too long: may not be more than 262144 bytes
```

### 07 블루/그린

```bash
kubectl apply -f 07-argo-rollouts-bluegreen/rollout.yaml
kubectl argo rollouts set image web-bg web=nginx:1.27
kubectl argo rollouts get rollout web-bg
```
```
Status:   ॥ Paused   Message: BlueGreenPause
Images:   nginx:1.26 (stable, active)
          nginx:1.27 (preview)
active selector:  {"app":"web-bg","rollouts-pod-template-hash":"5fb69d4965"}   ← 블루
preview selector: {"app":"web-bg","rollouts-pod-template-hash":"55b5689b6b"}   ← 그린
```
```bash
kubectl argo rollouts promote web-bg
```
```
revision:2  web-bg-55b5689b6b  stable,active
revision:1  web-bg-5fb69d4965  delay:9m51s     ← scaleDownDelaySeconds 600
```
```bash
kubectl argo rollouts undo web-bg      # 블루가 남아 있는 동안
```
```
active -> blue after 0s
```

### 08 카나리 (라우터 없음, 레플리카 10)

```bash
kubectl apply -f 08-argo-rollouts-canary/rollout.yaml
kubectl argo rollouts set image web-canary web=nginx:1.27
```
```
Status: ॥ Paused  Message: CanaryPauseStep  Step: 1/4  SetWeight: 20  Updated: 2   ← 10개 중 2개
```
```bash
kubectl argo rollouts promote web-canary
```
```
Step: 3/4  SetWeight: 50  Updated: 5
(20초 뒤) Status: ✔ Healthy  Step: 4/4  SetWeight: 100
```
항상 실패하는 판정(`analysis-abort.yaml`)을 20% 뒤에 넣고 다시 배포:
```
Status:  ✖ Degraded
Message: RolloutAborted: Rollout aborted update to revision 3: Step-based analysis phase error/failed:
         Metric "smoke" assessed Failed due to failed (1) > failureLimit (0)
Step: 0/4  SetWeight: 0  Updated: 0   Images: nginx:1.27 (stable)
spec image after abort: nginx:1.27-alpine      ← 원하는 상태는 새 버전 그대로
```

### 09 Argo CD

```bash
kubectl apply -f 09-argocd/application.yaml
```
```
1) Synced/Healthy
2) selfHeal=false 에서 손으로 replicas 3: OutOfSync, replicas=3   ← 표시만 한다
3) selfHeal=true 로 바꾼 뒤: replicas=1, Synced                    ← 깃 값으로 되돌린다
```
```bash
argocd app rollback guestbook 0 --core
```
```
rpc error: code = FailedPrecondition desc = rollback cannot be initiated when auto-sync is enabled
```

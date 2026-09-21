# 실습 중 막히는 자리

실습을 이어서 하다 보면 앞 모듈이 남긴 것 때문에 막힌다. 클러스터를 6일, 10일 그대로
두고 쓰면 특히 그렇다. 자주 걸리는 것들을 에러 메시지 기준으로 모았다.

메시지를 그대로 검색하기보다 **무엇이 남아 있어서 막는지**를 먼저 본다. 대부분
고장이 아니라 안전장치가 제 일을 한 것이다.

---

## 1. 인그레스 — 같은 호스트·경로를 둘이 주장한다

```
Error from server (BadRequest): admission webhook "validate.nginx.ingress.kubernetes.io"
denied the request: host "journal.local" and path "/api" is already defined
in ingress journal/journal
```

### 왜

ingress-nginx의 어드미션 웹훅이 **같은 호스트와 경로를 두 인그레스가 주장하는 것**을
막는다. **네임스페이스가 달라도 막힌다** — 호스트 이름은 클러스터 전체에서 하나이기
때문이다.

M14에서 `kubectl apply -k`로 만든 인그레스가 살아 있는데 M28에서 같은 앱을 차트로
다시 올리면 여기서 부딪힌다. 두 정의가 같은 앱을 가리키므로 호스트도 같다.

### 확인

```
kubectl get ingress -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,HOST:.spec.rules[*].host,PATH:.spec.rules[*].http.paths[*].path'
```

### 푸는 법

앞의 것을 내리고 새로 올릴 거면:

```
kubectl delete ingress journal -n journal
```

둘을 같이 두고 비교할 거면 호스트를 갈라 준다:

```
helm upgrade --install dev course/labs/charts/journal \
  -n journal-dev --create-namespace \
  -f course/labs/charts/journal/values-dev.yaml \
  --set ingress.host=dev.journal.local
```

`/etc/hosts`에도 그 이름을 넣어야 브라우저에서 열린다.

```
echo '127.0.0.1 dev.journal.local' | sudo tee -a /etc/hosts
```

### 이 에러는 보통 혼자 오지 않는다

인그레스에서 막히면 헬름 설치가 중간에 깨지고, **실패한 릴리스 기록이 남는다.**
그래서 같은 명령을 다시 치면 이번에는 2번 에러(`cannot reuse a name`)가 난다.
파드·서비스는 이미 만들어져 돌고 있는데 설치는 실패로 기록된 상태다.

둘을 한 번에 푸는 형태는 이것이다 — 호스트를 갈라 주고 `install` 대신
`upgrade --install` 로 실패한 릴리스를 이어서 고친다.

```
helm upgrade --install dev course/labs/charts/journal \
  -n journal-dev --create-namespace \
  -f course/labs/charts/journal/values-dev.yaml \
  --set ingress.host=dev.journal.local
```

확인은 두 줄이다. `STATUS deployed` 와 호스트 두 개가 보이면 풀린 것이다.

```
helm list -n journal-dev
kubectl get ingress -A
```

### 왜 이 충돌이 M28 에서 나는가

M28 은 같은 앱을 `k8s/journal/`(kustomize)과 `charts/journal/`(Helm) **두 벌로**
정의해 두고 그 차이를 실습 소재로 쓴다. 두 정의가 같은 앱을 가리키므로 호스트도 같고,
클러스터 단위 자원인 호스트 이름에서 정면으로 부딪힌다. 고장이 아니라 그 모듈이
보여 주려는 장면이다.

---

## 2. 헬름 — 이름이 이미 쓰이고 있다

```
Error: INSTALLATION FAILED: release name check failed:
cannot reuse a name that is still in use
```

### 왜

`helm install`은 **새로 만드는** 명령이라 같은 네임스페이스에 같은 이름이 있으면
거부한다. 주의할 점은 **실패한 릴리스도 이름을 점유한다**는 것이다.

```
NAME  NAMESPACE    REVISION  STATUS  CHART
dev   journal-dev  1         failed  journal-0.2.0
```

1번 인그레스 충돌로 설치가 중간에 깨지면 이 상태가 남는다. 파드·서비스는 이미
만들어져 돌고 있고 인그레스 하나만 실패한 경우가 흔하다 — 그래서 "설치가 안 됐는데
파드는 떠 있는" 모양이 된다.

### 확인

```
helm list -A
kubectl get secret -A -l owner=helm -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,STATUS:.metadata.labels.status'
```

`helm list`는 기본적으로 `deployed`만 보여 준다. 실패본까지 보려면 두 번째 명령이
확실하다.

### 푸는 법

**이어서 고치려면** `install` 대신 `upgrade --install`을 쓴다. 없으면 설치하고 있으면
갱신하므로 여러 번 쳐도 결과가 같다.

```
helm upgrade --install dev course/labs/charts/journal \
  -n journal-dev -f course/labs/charts/journal/values-dev.yaml
```

**깨끗이 다시 하려면** 지우고 시작한다.

```
helm uninstall dev -n journal-dev
```

> 실습을 이어서 할 때는 `helm install` 대신 항상 `helm upgrade --install`을 쓴다.
> 이 한 줄로 이 에러의 대부분이 사라진다.

---

## 3. 헬름 — 스키마가 값을 거부한다

```
Error: values don't meet the specifications of the schema(s) in the following chart(s):
journal:
- at '/redis/password': minLength: got 0, want 1
```

### 왜

환경변수가 비어 있다. `--set redis.password="$REDIS_PASSWORD"`에서 변수가 안 잡혀
있으면 **빈 문자열이 그대로 들어가고**, 차트의 `values.schema.json`이 그것을 거부한다.
스키마가 제 일을 한 것이다 — 비밀번호 없이 레디스가 뜨는 편이 더 나쁘다.

### 확인

```
echo "길이 ${#REDIS_PASSWORD}"
```

`0`이면 이 경우다.

### 푸는 법

```
export REDIS_PASSWORD=$(openssl rand -base64 24)
echo "길이 ${#REDIS_PASSWORD}"
```

셸을 새로 열면 사라지므로, 실습을 이어서 할 때마다 다시 넣거나 `.env` 파일로 관리한다.
`--set`으로 넘긴 값은 릴리스 기록에 평문으로 남는다는 점도 알아 둔다(M31의 SOPS가
그 문제를 다룬다).

---

## 4. 파드 — 이미 있다

```
Error from server (AlreadyExists): pods "curlbox" already exists
```

### 왜

`kubectl run`도 **새로 만드는** 명령이다. 앞 모듈에서 만든 임시 파드가 아직 돌고 있다.

### 푸는 법

그대로 쓰면 되는 경우가 많다. 상태부터 본다.

```
kubectl get pod curlbox -o wide
```

`Running`이면 들어가면 된다.

```
kubectl exec -it curlbox -- sh
```

다시 만들 거면 지우고, 일회용이면 `--rm`을 붙인다.

```
kubectl delete pod curlbox
kubectl run probe --rm -it --image=curlimages/curl:8.19.0 --restart=Never -- sh
```

---

## 5. kind — 클러스터가 이미 있다

```
ERROR: failed to create cluster: node(s) already exist for a cluster with the name "study"
```

### 왜

설정 파일의 `name`과 같은 클러스터가 이미 있다. 덮어쓰지 않고 거부하는 것이 안전장치다.

### 확인

```
kind get clusters
kubectl get nodes -o wide
docker ps --filter "label=io.x-k8s.kind.cluster"
```

노드가 `Ready`면 그대로 쓰면 된다. 이미지 버전도 확인한다.

```
docker ps --filter "label=io.x-k8s.kind.cluster=study" --format '{{.Names}}\t{{.Image}}'
```

### 푸는 법

**먼저 그대로 쓸 수 있는지 본다.** 노드가 `Ready` 면 지울 이유가 없다.

정말 새로 만들어야 할 때만 지운다. 아래 명령은 **되돌릴 수 없다** — 노드 컨테이너가
삭제되므로 그 클러스터에 올려 둔 것이 전부 사라진다. 네임스페이스, 헬름 릴리스,
PVC 의 데이터, 관측 스택이 모은 시계열까지 함께 간다.

```
kind delete cluster --name study
```

> 실습을 며칠에 걸쳐 이어 하고 있다면 이 명령을 치기 전에 멈춘다.
> 대개는 네임스페이스 하나만 지우면 되고(마지막 절 참조), 그쪽이 훨씬 싸다.
> 지운 뒤 `kubectl` 이 전부 깨지는 것은 8번 항목과 같은 증상이다.

---

## 6. 도커 빌드 — `load metadata` 에서 멈춘다

```
#2 [internal] load metadata for docker.io/library/node:24-alpine
```

여기서 몇 분씩 진행이 없으면 베이스 이미지를 받아 오는 길이 막힌 것이다.

### 가르는 법

로컬에 있는 이미지로 바꿔 시험한다. 그것이 몇 초 만에 끝나면 **네트워크·데몬 문제**이고,
그것도 멈추면 데몬 자체가 물린 것이다.

```
docker images | grep -E '^(node|alpine)'
docker pull hello-world        # 아무 이미지나 받아지는지
```

### 푸는 법

베이스 이미지를 먼저 따로 받아 두면 빌드는 그 단계를 건너뛴다.

```
docker pull node:24-alpine
```

그래도 멈추면 Docker Desktop을 재시작한다. 데몬의 레지스트리 경로가 일시적으로
물리는 경우가 있고, 재시작으로 풀린다.

---

## 7. 게이트웨이 — 서비스가 안 보인다

```
Error from server (NotFound): services "journal-gateway-nginx" not found
```

### 왜

이 서비스는 `Gateway` 리소스가 만들어지고 **컨트롤러가 그것을 집어 간 뒤에야** 생긴다.
Gateway를 적용하기 전에 치면 없는 것이 맞다.

### 확인

```
kubectl get gateway -A
kubectl get gatewayclass
```

`PROGRAMMED`가 `True`여야 데이터 플레인이 떴다는 뜻이다. `False`로 오래 남아 있으면
`gatewayClassName`이 어느 구현체도 가리키지 않는 것이다.

### 주의 — 구현체가 둘 이상일 때

클러스터에 게이트웨이 구현체가 여럿 설치돼 있으면 `gatewayClassName`을 명시해야 한다.

```
kubectl get gatewayclass
NAME    CONTROLLER                                      ACCEPTED
eg      gateway.envoyproxy.io/gatewayclass-controller   True
nginx   gateway.nginx.org/nginx-gateway-controller      True
```

이름이 틀리면 어느 컨트롤러도 집어 가지 않고, **그 사실을 알려 주는 이벤트도 없다.**

---

## 8. kubectl — `invalid character '<'`

```
E0918 14:16:08 memcache.go:381] "Couldn't get current server API group list"
err="invalid character '<' looking for beginning of value"
error: invalid character '<' looking for beginning of value
```

### 왜

kubeconfig 에 **현재 컨텍스트가 없다.** 그러면 kubectl 이 옛 기본값
`http://localhost:8080` 으로 간다. 그 포트에 웹 애플리케이션이 떠 있으면 JSON 대신
HTML 이 돌아오고, 그 첫 글자 `<` 에서 파싱이 깨진다.

**8080 의 웹앱은 죄가 없다.** kubectl 이 갈 곳을 잃어 거기로 간 것뿐이다.
이 상태에서는 `kubectl` 명령이 전부 같은 에러를 낸다.

가장 흔한 원인은 **클러스터를 지운 것**이다. `kind delete cluster` 는 노드 컨테이너를
지우면서 kubeconfig 에서 컨텍스트도 빼 간다. 그것이 유일한 컨텍스트였다면 파일이
껍데기만 남는다.

### 확인

```
kubectl config current-context
kind get clusters
ls -l ~/.kube/config
```

`current-context is not set` · `No kind clusters found` · 설정 파일이 수십 바이트면
이 경우다. 8080 에 누가 있는지도 보면 확실해진다.

```
curl -s -o /dev/null -w '%{http_code} %{content_type}\n' http://localhost:8080/
```

### 푸는 법

컨텍스트만 빠졌고 클러스터는 살아 있는 경우:

```
kubectl config get-contexts
kubectl config use-context kind-study
```

클러스터 자체가 없으면 다시 만든다. 아래 "막힌 실습을 처음부터 다시" 로 간다.

> **컨테이너가 중지가 아니라 삭제라면 되살릴 수 없다.**
> `docker ps -a --filter "label=io.x-k8s.kind.cluster"` 에 아무것도 안 나오면
> 그 클러스터의 실습 결과는 사라진 것이다.

---

## 되풀이되는 원칙 셋

**하나 — `install`보다 `upgrade --install`.** `helm install`·`kubectl run`·`kubectl create`는
전부 "새로 만드는" 명령이라 두 번째 실행에서 막힌다. 실습을 이어서 할 때는 여러 번
쳐도 결과가 같은 형태를 쓴다.

| 막히는 것 | 대신 |
|---|---|
| `helm install` | `helm upgrade --install` |
| `kubectl create -f` | `kubectl apply -f` |
| `kubectl run` | `--rm` 을 붙이거나 `apply -f -` 로 |

**둘 — 거부는 대개 안전장치다.** 어드미션 웹훅, 스키마 검증, 이름 중복 검사는 전부
"그대로 두면 더 나쁜 상태가 된다"고 막는 것이다. 우회할 방법을 찾기 전에 **무엇을
막고 있는지**부터 읽는다.

**셋 — 앞 모듈의 산출물을 의심한다.** 클러스터를 오래 두고 쓰면 M09의 실패 실습 파드,
M12의 게이트웨이, M14의 인그레스가 그대로 남아 뒤쪽 실습을 막는다. 막히면 먼저
무엇이 남아 있는지 센다.

```
kubectl get all -A | grep -v 'kube-system\|monitoring'
helm list -A
kubectl get ingress,gateway -A
```

`kubectl get all`은 컨피그맵·시크릿·PVC·인그레스를 보여 주지 않는다. 남은 것을
빠짐없이 세려면 이렇게 한다.

```
kubectl api-resources --verbs=list --namespaced -o name \
  | xargs -n1 kubectl get --show-kind --ignore-not-found -n <네임스페이스>
```


helm list -n journal-dev
kubectl get ingress -A

---

## 막힌 실습을 처음부터 다시

앞 모듈 산출물이 꼬여서 되돌리기 어려우면 네임스페이스째 지우는 것이 가장 빠르다.
네임스페이스를 지우면 그 안의 리소스가 전부 사라진다.

```
kubectl delete namespace journal
bash course/labs/scripts/rebuild.sh
```

`rebuild.sh`는 빈 클러스터에서 M14 시점 상태까지 한 번에 복구한다. 뒤쪽 모듈에서
꼬였을 때의 탈출구다.

### 복구가 됐는지 확인하는 네 줄

`rebuild.sh` 가 끝나면 위에서부터 차례로 친다. 한 줄이라도 기대값과 다르면 거기서
멈추고 원인을 찾는다 — 그 상태로 다음 모듈을 이어가면 더 찾기 어려워진다.

```
kubectl config current-context
kubectl get nodes
kubectl -n journal get pods
curl -H 'Host: journal.local' http://localhost:18080/api/entries
```

| 명령 | 기대값 |
|---|---|
| `config current-context` | `kind-study` |
| `get nodes` | 3개 모두 `Ready` |
| `-n journal get pods` | 전부 `Running` · `RESTARTS 0` |
| `curl …/api/entries` | JSON 응답 (빈 배열이어도 정상) |

마지막 줄이 `Connection refused` 면 인그레스 컨트롤러가 아직 안 떴거나 `18080` 포트
매핑이 없는 것이다. `kubectl -n ingress-nginx get pods` 로 컨트롤러부터 본다.

`rebuild.sh` 는 **M14 시점까지만** 복구한다. 그 뒤 모듈의 산출물(관측 스택 · 정책 ·
GitOps · 카오스)은 해당 모듈을 다시 따라가야 한다.

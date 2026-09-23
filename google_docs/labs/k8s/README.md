# 10장 매니페스트 — 빌드부터 접속까지

문서 10.3~10.4절의 `service.yml` · `deployment.yml` 이다. 원문은 레지스트리에 이미지를
올려 두고 쓰지만, 여기서는 **레지스트리 없이** kind 노드에 직접 넣는다. 로컬 실습에서는
그쪽이 손이 덜 가고 실패할 자리도 적다.

```
service.yml       LoadBalancer 타입 서비스 (8080 → 8080)
deployment.yml    replicas 3 · readinessProbe /hello
```

## 1. 이미지를 만든다

앱 소스는 옆 디렉터리에 있다. 로컬에 JDK 나 Gradle 이 없어도 된다 — Dockerfile 의
빌더 스테이지가 컨테이너 안에서 빌드까지 끝낸다.

```
cd google_docs/labs/k8s-sample-boot
docker build -t k8s-sample-boot:v1 .
```

확인:

```
docker images k8s-sample-boot
```

## 2. kind 노드에 적재한다

도커 데몬의 이미지 저장소와 kind 노드 안의 런타임 저장소는 **다른 공간**이다.
`docker images` 에 보인다고 파드가 뜨지는 않는다.

```
kind load docker-image k8s-sample-boot:v1 --name study
```

노드 3개에 각각 들어가므로 3줄이 나온다. 이미 같은 ID 가 들어 있으면
`found to be already present on all nodes.` 한 줄로 끝난다.

> 클러스터 이름이 `study` 가 아니면 `--name` 을 바꾼다. `kind get clusters` 로 확인한다.

## 3. 배포한다

```
cd -                                    # 저장소 루트로 돌아온다
kubectl apply -f google_docs/labs/k8s/deployment.yml
kubectl apply -f google_docs/labs/k8s/service.yml
```

## 4. 확인한다

```
kubectl rollout status deploy/k8s-sample-boot
kubectl get pods -l app=k8s-sample-boot
kubectl get svc k8s-sample-boot-service
```

| 명령 | 기대값 |
|---|---|
| `rollout status` | `successfully rolled out` |
| `get pods` | 3개 모두 `READY 1/1` · `Running` |
| `get svc` | `TYPE LoadBalancer` · `EXTERNAL-IP <pending>` |

`EXTERNAL-IP` 가 `<pending>` 인 것은 **정상이다.** 클라우드 로드밸런서를 붙여 줄
컨트롤러가 kind 에는 없다. 문서가 클라우드를 전제로 쓰였기 때문이고, 고장이 아니다.

## 5. 호출한다

`<pending>` 이므로 포트포워드로 들어간다.

```
kubectl port-forward svc/k8s-sample-boot-service 8080:8080
```

다른 터미널에서:

```
curl localhost:8080/hello
```

응답에 호스트명이 섞여 나온다. 여러 번 치면 **파드마다 다른 이름**이 돌아오는 것을
볼 수 있다 — 서비스가 3개에 나눠 보내고 있다는 뜻이다.

> 포트포워드는 터미널을 닫으면 끊긴다. 끝나면 `Ctrl-C` 로 종료한다.

## 정리

```
kubectl delete -f google_docs/labs/k8s/service.yml
kubectl delete -f google_docs/labs/k8s/deployment.yml
```

## 막히면

**`ImagePullBackOff`** — 2번 적재를 건너뛴 것이다. `kind load` 를 다시 한다.
노드 안에 들어갔는지는 여기서 본다.

```
docker exec study-control-plane crictl images | grep k8s-sample-boot
```

**파드가 `Running` 인데 `READY 0/1`** — 레디니스 프로브가 아직 통과하지 못한 것이다.
`/hello` 가 200 을 주기까지 기다린다. 오래 걸리면 로그를 본다.

```
kubectl logs -l app=k8s-sample-boot --tail=30
```

**엔드포인트가 비어 있다** — 서비스 셀렉터와 파드 레이블이 어긋난 것이다. 둘 다
`app: k8s-sample-boot` 여야 한다.

```
kubectl get endpointslices -l kubernetes.io/service-name=k8s-sample-boot-service
```

그 밖의 에러는 [`../TROUBLESHOOTING.md`](../TROUBLESHOOTING.md) 를 본다.

## 원문과 다른 점

| | 문서 원문 | 여기 |
|---|---|---|
| 이미지 배포 | 레지스트리에 push 후 pull | `kind load docker-image` |
| 이미지 이름 | `localhost:5000/demo/k8s-sample-boot:v1` | `k8s-sample-boot:v1` |

원문 값은 `deployment.yml` 주석에 남겨 두었다. 레지스트리를 쓰는 환경으로 옮길 때
그 줄로 되돌리면 된다.

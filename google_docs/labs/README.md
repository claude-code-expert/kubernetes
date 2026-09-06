# labs — Kubernetes_시작하기_2026.docx 실습 파일

> 애플리케이션 소스의 **정본은 별도 저장소**에 있다 —
> https://github.com/villainscode/kubernetes (`k8s-sample-boot`, `docker-sample`).
> 이 디렉터리의 파일들은 그 사본이며, 둘이 어긋나면 저장소를 기준으로 맞춘다.

문서의 코드 블록이 정본이고 이 디렉터리는 그 추출본이다. 둘이 어긋나면 문서를 기준으로 맞춘다.

```
labs/
├── k8s-sample-boot/          9~22장의 실습 앱 (Spring Boot). 아래 README 참조
├── k8s/sample/               15장 매니페스트 한 벌 (00~30 순서대로 적용)
├── charts/sample-app/        15장 Helm 차트
└── monitoring/dashboards/    22장 Grafana 대시보드 JSON
```

## 빠른 시작

```bash
# 1) 앱 이미지 빌드 (로컬 JDK 불필요 — Dockerfile 에 빌더 스테이지가 있다)
cd google_docs/labs/k8s-sample-boot
docker build -t demo/k8s-sample-boot:v1 .

# 2) 클러스터에 이미지 넣기 — 아래 셋 중 하나
kind load docker-image demo/k8s-sample-boot:v1 --name study   # kind CLI
docker tag demo/k8s-sample-boot:v1 localhost:5000/demo/k8s-sample-boot:v1 \
  && docker push localhost:5000/demo/k8s-sample-boot:v1        # 로컬 레지스트리 (문서 9.4절)
# Docker Desktop 의 kubeadm 프로비저너면 호스트 이미지를 그대로 보므로 아무것도 안 해도 된다

# 3) 배포 — 10장 방식 (단일 디플로이먼트)
kubectl apply -f - <<'YAML'
... 문서 10.3~10.4절의 service.yml / deployment.yml
YAML

#    또는 15장 방식 (레디스까지 포함한 한 벌)
kubectl apply -f google_docs/labs/k8s/sample/

#    또는 Helm (15.5절)
helm install dev google_docs/labs/charts/sample-app -n sample-helm --create-namespace --wait
```

## 문서와 다른 점 — 읽고 시작한다

**Dockerfile 이 문서보다 한 단계 길다.** 문서 10.2절은 로컬에서 `./gradlew clean build` 로
jar 를 먼저 만든 뒤 그 jar 를 복사하는 단일 스테이지 Dockerfile 이다. 로컬에 JDK 가 있어야 한다.

이 디렉터리의 `Dockerfile` 은 앞에 빌더 스테이지를 하나 더 둬서 컨테이너 안에서 Gradle 빌드까지
끝낸다. **로컬에 JDK 가 없어도 `docker build` 한 줄로 된다.** 최종 실행 이미지
(`eclipse-temurin:17-jre`)와 실행 명령은 문서와 같다.

로컬에 JDK 21 이 있고 문서 그대로 따라 하고 싶으면 빌더 스테이지를 지우고
`./gradlew clean build` 를 먼저 실행하면 된다.

## 이미지 세 벌

| 태그 | 무엇이 다른가 | 쓰는 곳 |
|---|---|---|
| `v1` | `/hello` 가 `Hello World! V1` 을 반환 | 10장 배포 |
| `v2` | 문자열만 `V2` 로 | 11장 롤링 업데이트·롤백 |
| `v3` | Actuator + Micrometer 추가. `/actuator/prometheus` 노출 | 21~22장 관측 |

v2·v3 를 만들려면 `IndexController.java` 의 문자열 두 곳(`Hello World! V1`, 로그의 `V1`)을 바꾸고
다시 빌드한다. v3 는 추가로 `build.gradle` 의 actuator·micrometer 의존성과
`src/main/resources/application.properties` 가 필요하다 — 둘 다 이미 들어 있으므로
현재 상태로 빌드하면 v3 에 해당한다.

```bash
docker build -t demo/k8s-sample-boot:v3 .
```

## 확인

```bash
kubectl exec curlbox -- curl -s http://k8s-sample-boot-service:8080/hello
# Hello World! V3 (Host = k8s-sample-boot-755879697-p8x8q)

kubectl exec curlbox -- curl -s http://k8s-sample-boot-service:8080/actuator/prometheus | head
```

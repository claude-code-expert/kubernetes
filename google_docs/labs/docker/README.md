# labs/docker — Docker_시작하기_2026.docx 실습 파일

문서의 코드 블록이 정본이고 이 디렉터리는 그 추출본이다.

## 실습 대상 소스

**정본은 별도 저장소에 있다** — https://github.com/villainscode/kubernetes

```bash
git clone https://github.com/villainscode/kubernetes.git
cd kubernetes/docker-sample
docker build -f Dockerfile.multi -t docker-sample:multi .
```

Spring Boot 4.1.0 / JDK 21 / Maven. Dockerfile 에 빌더 스테이지가 있어
로컬에 JDK 나 Maven 이 없어도 빌드된다.

이 디렉터리의 파일들은 그 저장소의 사본이다. 둘이 어긋나면 저장소를 기준으로 맞춘다.

## 파일

| 파일 | 쓰는 곳 | 결과 |
|---|---|---|
| `Dockerfile.naive` | 8.1 · 8.3 | 한 스테이지에서 빌드까지 → 1.02GB |
| `Dockerfile.jre` | 8.1 | 미리 빌드한 jar 만 복사 → 475MB |
| `Dockerfile.multi` | 8.3 · 8.4 | 멀티스테이지 → 475MB |
| `Dockerfile.arg` | 8.6 | `--build-arg APP_VERSION` 으로 v1 · v2 |
| `compose-bad.yaml` | 13장 | `depends_on` 만 — 뒤 서비스가 Exited (1) |
| `compose-good.yaml` | 13장 | `healthcheck` + `condition: service_healthy` |
| `kind-1node.yaml` | 16.2 | 단일 노드 kind 클러스터 정의 |

## 빠른 확인

```bash
# 8장 — 크기 비교
docker build -f Dockerfile.naive -t docker-sample:naive .
docker build -f Dockerfile.multi -t docker-sample:multi .
docker images docker-sample

# 15장 — 스캔
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:0.74.0 image --scanners vuln --severity HIGH,CRITICAL docker-sample:multi

# 16장 — 클러스터
kind create cluster --config kind-1node.yaml
kind load docker-image docker-sample:multi --name docker-study
kubectl run t --image=docker-sample:multi --image-pull-policy=IfNotPresent
kind delete cluster --name docker-study
```

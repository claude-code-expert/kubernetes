# labs/docker — Docker_시작하기_2026.docx 실습 파일

문서의 코드 블록이 정본이고 이 디렉터리는 그 추출본이다.

## 실습 대상 소스

8장·12장의 실습 앱은 문서가 가리키는 외부 저장소를 그대로 쓴다.

```bash
git clone https://github.com/ceo-nomadlab/docker.git
cd docker
# 빌드 결과물(jar)이 저장소에 함께 커밋되어 있어 메이븐 없이도 바로 쓸 수 있다
ls -lh target/docker-0.0.1-SNAPSHOT.jar    # 19M
```

여기의 Dockerfile 들을 그 디렉터리에 복사해 넣고 빌드한다.

## 파일

| 파일 | 쓰는 곳 | 결과 |
|---|---|---|
| `Dockerfile.naive` | 8.1 | JDK 베이스 + 전체 복사 → 492MB |
| `Dockerfile.jre` | 8.1 | JRE 베이스 + jar 만 → 396MB |
| `Dockerfile.buildinimage` | 8.3 | 한 스테이지로 빌드까지 → 730MB |
| `Dockerfile.multi` | 8.3 · 8.4 | 멀티스테이지 → 396MB |
| `Dockerfile.arg` | 8.6 | `--build-arg APP_VERSION` 으로 v1 · v2 |
| `compose-bad.yaml` | 13장 | `depends_on` 만 — 뒤 서비스가 Exited (1) |
| `compose-good.yaml` | 13장 | `healthcheck` + `condition: service_healthy` |
| `kind-1node.yaml` | 16.2 | 단일 노드 kind 클러스터 정의 |

## 빠른 확인

```bash
# 8장 — 크기 비교
docker build -f Dockerfile.naive -t springboot:naive .
docker build -f Dockerfile.multi -t springboot:multi .
docker images springboot

# 15장 — 스캔
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:0.74.0 image --scanners vuln --severity HIGH,CRITICAL springboot:multi

# 16장 — 클러스터
kind create cluster --config kind-1node.yaml
kind load docker-image springboot:multi --name docker-study
kubectl run t --image=springboot:multi --image-pull-policy=IfNotPresent
kind delete cluster --name docker-study
```

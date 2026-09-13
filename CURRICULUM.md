# 도커 & 쿠버네티스 — 이론 + 따라하기 전체 커리큘럼

목표: 컨테이너를 한 번도 실행해본 적 없는 사람이 38개 모듈을 순서대로 따라 하면
빈 노트북에서 관측·보안·GitOps·카오스 검증까지 갖춘 클러스터를 스스로 세운다.

- 이론 축: 『쿠버네티스 창시자에게 배우는 모범 사례 2판』(한빛미디어, 2024) 21개 장 목차
- 실습 축: 로컬 kind 클러스터에서 전 과정 재현. 클라우드 계정 없이 완주 가능
- 산출 형식: 모듈당 HTML 1편 (`course/mNN-*.html`) + 실습 파일 (`course/labs/`)
- 기존 자산: `docs/chapter0~21`, `docs/kubenetes/day01~14`, `docs/k8s-observability-study`
  는 재사용·확장 대상이며 원본은 수정하지 않는다

## 난이도 5단계 — 명령이 어떻게 올라가는가

교재 전체에서 같은 대상을 세 번 다룬다. 같은 오브젝트를 다른 깊이로 반복하는 것이
이 커리큘럼의 학습 설계다. **단계는 파트 경계와 정확히 일치**하며, 각 모듈 HTML 첫머리의
난이도 표시가 이 표를 따른다.

| 단계 | 모듈 | 회당 평균 | 명령의 성격 | 예 |
|---|---|---|---|---|
| 초반 | M01~M07 | 55분 | 한 줄 명령으로 만들고 눈으로 확인 | `docker run`, `docker build`, `docker compose up` |
| 초반→중반 | M08~M14 | 70분 | 쿠버네티스 오브젝트를 만들고 YAML로 다시 쓴다 | `kubectl create deployment`, `kubectl expose`, `kubectl apply -k`, `helm install` |
| 중반 | M15~M22 | 90분 | 선언형으로 고치고 **실패를 재현**한다 | `kubectl apply -f`, `kubectl top`, `kubectl drain`, PromQL `rate()`·`histogram_quantile()` |
| 중후반 | M23~M27 | 95분 | 권한·정책·감사로 **사람이 못 하게** 막는다 | `kubectl auth can-i`, PSA 라벨, `NetworkPolicy`, `ValidatingAdmissionPolicy` |
| 후반 | M28~M38 | 115분 | 사람이 apply 하지 않는다. 파이프라인·정책·실험이 대신한다 | `kubectl argo rollouts promote`, Argo CD `Application`, `kubectl apply -f podchaos.yaml`, `k6 run` |

시간은 **읽기 + 명령 실행 + 대기(롤아웃·분석·부하)**를 더해 산정한 값이고 숙련도에 따라
±30% 차이가 난다. 전체 합은 약 **55시간**이다.

같은 주제의 3단계 예 — 배포:
1. M08 `kubectl create deployment web --image=...` (명령형, 1줄)
2. M10 `kubectl apply -f deployment.yaml` + `rollout undo` (선언형, 이력)
3. M30 카나리 20% → 판단 메트릭(성공률 0.95)으로 승격/롤백 (자동 판정, 사람이 치는 명령 0)

## 고정 버전 매트릭스 (2026-09-03 확인)

| 구성요소 | 버전 | 확인처 | 함정 |
|---|---|---|---|
| Kubernetes | **1.37.0** (2026-08-26 릴리스, EOL 2027-10-28). 지원 라인 1.35 / 1.36 / 1.37 | kubernetes.io/releases | 실습은 1.37 고정. 사내 클러스터가 1.35면 차이 나는 API만 각주 |
| kind | **v0.33.0**, 노드 이미지 `kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5` | github.com/kubernetes-sigs/kind/releases | 다이제스트까지 적어야 재현된다. 호스트와 이미지 아키텍처 일치 필수 |
| Docker Engine | **29.x** (Desktop은 별도 버전 체계) | docs.docker.com/engine/release-notes/29 | 실습 당일 `docker version`으로 재확인. 29.7의 임베디드 containerd는 실험 기능 — 쓰지 않는다 |
| Helm | **4.x** 기준으로 작성, Helm 3는 3.22.0(2026-09-09)이 마지막 기능 릴리스이고 보안 지원 2027-02-10 종료 | helm.sh | Helm 3 사용자를 위한 차이(명령·차트 API)를 모듈 M28에 별도 절로 |
| Gateway API | **v1.6.1** Standard (TCPRoute·UDPRoute GA, 실험 리소스는 `gateway.networking.x-k8s.io`로 분리) | kubernetes.io/blog/2026/08/03 | Ingress는 유지보수 모드. 신규 설계는 Gateway API로 가르치고 Ingress는 존치 자산으로 |
| kube-prometheus-stack | **차트 89.2.2** / Prometheus Operator v0.93.1 | prometheus-community | 2026-09-05 확인. 데이터소스는 uid로만 참조. kind 기본 설정에서는 컨트롤 플레인 타깃 4종이 DOWN 이다 — M19의 실패 재현 소재 |
| Loki / 로그 수집기 | Loki 3.7.x + **Grafana Alloy** | grafana-community 저장소 | **Promtail은 2026-03-02 EOL. 검색 결과에 여전히 나오지만 쓰지 않는다** |
| 카오스 도구 | **Chaos Mesh v2.8.4** | chaos-mesh.org | 책의 Chaos Toolkit은 0.39.0(2024-04) 이후 릴리스 없음 — 대체 |
| 부하 도구 | k6 | grafana.com/docs/k6 | `ab`·`wrk`는 시나리오 표현력 부족 |
| 실습 앱 ① `journal-api` | Node 22 / Express 5 / TypeScript | course/labs/apps/journal-api | M04~M18 대상. 빌드가 빨라 M04 캐시 실험·M07 공급망 실습이 성립한다 |
| 실습 앱 ② `order-api` | Spring Boot 4.1.0 / JDK 21 / Gradle | docs/kubernetes-monitoring/labs | M19~M38 대상. `/actuator/prometheus`·ChaosController 보유. 빌드에 JDK 21·Gradle 필요 |
| metrics-server | **v0.9.0** (2026-07-13, 호환 1.34+) | kubernetes-sigs/metrics-server | kind 기본 미포함. `--kubelet-insecure-tls` 없이는 파드가 Ready 가 되지 않는다(kubelet 인증서에 IP SAN 이 없다). M16 `kubectl top`·M17 HPA의 전제라 M01에서 설치한다 |

버전 숫자를 적는 모든 문서에 확인일과 "실습 당일 재확인" 안내를 함께 넣는다.

---

# Part 0. 실습 환경 (M01)

## M01. 환경 구축과 버전 고정
- 이론: 로컬 클러스터 선택지(kind / minikube / Docker Desktop 내장 / Colima) 비교는 나열이 아니라 선택 근거만. 왜 kind 3노드인가 — 스케줄링·어피니티·PDB 실습에 노드가 2개 이상 필요하다
- 실습: Docker Desktop(또는 Colima) 설치 → 리소스 할당 → `kind create cluster --config` 3노드 → `kubectl`·`helm`·`k6`·JDK 21 설치 → metrics-server 설치(`--kubelet-insecure-tls`) → preflight 스크립트로 자동 점검
- 명령: `docker version`, `kind create cluster`, `kubectl cluster-info`, `kubectl get nodes -o wide`, `kubectl config current-context`
- 산출물: `labs/infra/kind-cluster.yaml`(노드 이미지를 `@sha256` 다이제스트까지 고정), `labs/scripts/preflight.sh`. `labs/scripts/rebuild.sh`는 M14에서 완성되며 M01은 존재만 예고한다
- 검증: 노드 3개 Ready, `kubectl get --raw='/readyz?verbose'` 전 항목 ok, `kubectl top nodes`가 수치를 돌려준다
- 재사용: `docs/chapter0/ch00-local-setup.html`, `docs/k8s-observability-study/00·01`

---

# Part 1. 도커 (M02~M07) — 초반

책 1장 이전의 전제. 책은 컨테이너 빌드를 다루지 않으므로(1.3.1에서 명시) 이 파트는
공식 문서와 기존 `docs/kubenetes/day01`, `docs/docker-basic` 자산을 기준으로 신규 구성한다.

## M02. 컨테이너는 프로세스다
- 이론: 네임스페이스·cgroup v2로 격리된 호스트 프로세스. VM과 다른 점을 그림 한 장으로. 이미지-컨테이너-프로세스 3층
- 실습: nginx 실행 → 포트 매핑 → 로그 → 셸 접속 → 중지·삭제. 호스트에서 `ps`로 같은 프로세스 확인. `--memory` 제한 걸고 OOM 관찰
- 명령: `run -d -p`, `ps`, `logs -f`, `exec -it`, `stats`, `inspect`, `stop/rm`, `top`
- 후반 연결: 여기서 본 PID 1이 M15 preStop·SIGTERM 실습의 전제
- 검증: `docker inspect`의 `State.Pid`가 호스트 `ps`에 존재

## M03. 이미지와 레이어
- 이론: 읽기 전용 레이어 + 쓰기 가능 레이어, 콘텐츠 주소(다이제스트), 태그는 움직이는 포인터
- 실습: `pull` 진행 로그로 레이어 관찰 → `history`로 레이어별 크기 → 같은 이미지 태그 2개가 같은 다이제스트임을 확인 → `docker commit`으로 만든 이미지가 왜 재현 불가인지
- 명령: `pull`, `images --digests`, `history`, `inspect`, `tag`, `save/load`, `image prune`
- 책 연결: 1.3.1 이미지 관리 모범 사례 — 태그 전략, latest 금지의 근거를 여기서 처음 제시

## M04. Dockerfile — 빌드와 최적화
- 이론: 레이어 캐시가 깨지는 지점, 멀티스테이지, 베이스 이미지 선택(distroless는 셸이 없어 디버깅이 불편하다는 대가까지)
- 실습: 순진한 Dockerfile로 기준선 측정 → 캐시 실험(의존성 복사 순서 바꾸고 빌드 시간 비교) → 멀티스테이지로 디스크 사용량 1.68GB→246MB, 내려받는 크기 413MB→59MB → `.dockerignore` → `buildx`로 arm64/amd64 동시 빌드(M07 로컬 레지스트리로 푸시)
- 명령: `build -t`, `build --progress=plain`, `buildx build --platform`, `image ls`(크기 비교)
- 검증: 소스 한 줄 수정 후 재빌드가 캐시 히트로 몇 초 내 완료
- 책 연결: 5.4 컨테이너 빌드, 5.5 태깅

## M05. 데이터와 네트워크
- 이론: 컨테이너 파일시스템은 사라진다. volume / bind mount / tmpfs 차이. 브리지 네트워크와 컨테이너 DNS
- 실습: 볼륨에 Redis 데이터 두고 컨테이너 삭제 후 재생성해 데이터 생존 확인 → 사용자 정의 네트워크에서 컨테이너 이름으로 접속 → 기본 bridge에서는 이름 해석이 안 되는 것 확인(일부러 실패)
- 명령: `volume create/ls/inspect/rm`, `run -v`, `--mount`, `network create/connect/inspect`
- 후반 연결: 이 볼륨 개념이 M18 PV/PVC로 확장된다

## M06. Compose로 다중 서비스
- 이론: 여러 컨테이너를 손으로 관리하는 한계 → 선언형 파일. 쿠버네티스 매니페스트와의 유사점·차이점
- 실습: 앱 + Redis + Nginx 3서비스 compose 작성 → `healthcheck`와 `depends_on: condition: service_healthy` → `compose watch`로 개발 루프 → 스케일 `--scale`
- 명령: `docker compose up -d`, `ps`, `logs -f`, `exec`, `config`, `down -v`
- 검증: `compose config`가 병합 결과를 출력, 헬스체크 통과 후에만 앱이 뜬다

## M07. 레지스트리와 이미지 공급망
- 이론: 공급망 공격(책 1.3.1), 태그 vs 다이제스트 배포, SBOM과 서명, 취약점 스캔의 위치(CI)
- 실습: 로컬 `registry:3` 컨테이너 → 태깅·푸시·풀 → Docker Hub 푸시 → `docker scout cves`(또는 trivy)로 취약점 확인 → 베이스 이미지 교체 후 재스캔으로 감소 확인 → kind에 이미지 적재(`kind load docker-image`)
- 명령: `login`, `tag`, `push`, `pull <이미지>@sha256:...`, `scout cves`, `kind load docker-image`
- 책 연결: 5.5 태깅, 19.4 코드 보안
- 검증: 다이제스트로 pull 했을 때와 태그로 pull 했을 때 `docker image inspect -f '{{.Id}}'` 값이 같다
- 산출물: kind 노드 3개에 `journal-api:v1`과 `journal-api:v2` 적재. v2는 M10 롤아웃·M15 프로브 실습의 입력이다

---

# Part 2. 쿠버네티스 코어 (M08~M14) — 초반→중반

책 1장(기본 서비스 설치)과 2장(개발자 워크플로)이 이 파트의 이론 축. 마지막 M14에서
책 1장의 저널 애플리케이션 전체를 재현한다.

## M08. 클러스터 구조와 첫 배포
- 이론: 컨트롤 플레인 4종(apiserver·etcd·scheduler·controller-manager)과 노드 컴포넌트(kubelet·kube-proxy·CRI). 선언형 vs 명령형(책 1.2) — YAML이 진실 공급원인 이유
- 실습: 컴포넌트 파드 눈으로 확인 → 명령형 1줄 배포 → `describe`로 이벤트 읽기 → `port-forward`로 접속 → 파드를 지워도 되살아나는 것 확인
- 명령: `get nodes/pods -A`, `create deployment`, `get -o wide`, `describe`, `logs`, `exec`, `port-forward`, `delete pod`
- 검증: 파드 삭제 후 30초 내 새 파드 Running

## M09. 파드·레이블·네임스페이스
- 이론: 파드가 최소 배포 단위인 이유, 다중 컨테이너 패턴(사이드카·앰배서더), init 컨테이너, 네이티브 사이드카(`initContainers` + `restartPolicy: Always` — 1.29 베타·1.33 GA), 워크로드 컨트롤러 지도(Deployment/StatefulSet/DaemonSet/Job — M01에서 본 `kindnet`·`kube-proxy`가 데몬셋인 이유), 레이블 셀렉터가 모든 연결의 기반
- 실습: 파드 YAML 직접 작성 → 2컨테이너 파드에서 `localhost` 통신 확인 → init 컨테이너로 순서 강제 → 레이블 붙이고 셀렉터로 조회 → 네임스페이스 분리와 리소스 격리
- 명령: `apply -f`, `get po -l`, `label`, `annotate`, `explain`, `get -o jsonpath`, `create ns`, `-n`
- 책 연결: 2.3.2 네임스페이스 생성과 보안
- 일부러 실패: 레이블 오타로 셀렉터가 0개를 잡는 상황 재현

## M10. 디플로이먼트와 롤아웃
- 이론: ReplicaSet과의 관계, 의도한 상태 조정 루프, `maxSurge`/`maxUnavailable`, 리비전 이력
- 실습: 이미지 태그 v1→v2 롤링 업데이트를 `--watch`로 관찰 → 존재하지 않는 태그로 업데이트해 멈춤 재현 → `rollout undo` → `maxUnavailable: 0`으로 무중단 확인
- 명령: `set image`, `rollout status/history/undo/pause/resume`, `scale`, `get rs`
- 책 연결: 1.3.2, 6장 버저닝·릴리스·롤아웃
- 검증: 롤아웃 중 요청 루프에서 5xx 0건

## M11. 서비스와 클러스터 네트워크
- 이론: 파드 IP는 바뀐다. ClusterIP·NodePort·LoadBalancer·ExternalName 4종, EndpointSlice, kube-proxy(iptables/IPVS/nftables), CoreDNS 이름 규칙
- 실습: Service 생성 후 `endpointslices` 확인 → 파드 죽여 엔드포인트가 빠지는 것 관찰 → 다른 네임스페이스에서 FQDN 호출 → 셀렉터 불일치로 엔드포인트 0개 재현
- 명령: `expose`, `get svc/endpointslices`, `run -it --rm ... -- nslookup`, `describe svc`
- 책 연결: 9.1 서비스 · 9.2 서비스 디스커버리 · 9.3 인그레스와 로드밸런서

## M12. 인그레스와 Gateway API
- 이론: L7 진입점. Ingress의 현재 위치(유지보수 모드)와 Gateway API v1.6이 해결한 것 — 역할 분리(GatewayClass/Gateway/HTTPRoute), TCPRoute·UDPRoute GA
- 실습: ingress-nginx 설치 후 경로 기반 라우팅 → 같은 구성을 Gateway API로 다시 작성 → 헤더 기반 분기 → TLS 종료
- 명령: `helm install ingress-nginx`, `apply -f httproute.yaml`, `get gateway,httproute`, `curl -H "Host: ..."`
- 검증: `/` 는 파일 서버로, `/api` 는 API로 도달

## M13. 컨피그맵과 시크릿
- 이론: 설정을 이미지 밖으로. env vs 볼륨 마운트(볼륨만 갱신 반영), 불변 ConfigMap, 시크릿은 기본이 base64일 뿐 — etcd 저장 시 암호화·외부 시크릿 저장소가 필요한 이유
- 실습: ConfigMap 주입 2가지 방식 비교 → 값 변경 후 반영 차이 확인 → Secret 생성·마운트 → `immutable: true`로 수정 실패 재현
- 명령: `create cm --from-file/--from-literal`, `create secret generic`, `get secret -o jsonpath | base64 -d`, `rollout restart`
- 책 연결: 1.5, 1.6, 4.1~4.3

## M14. 종합 — 저널 애플리케이션과 Helm 파라미터화
- 이론: 책 1장 전체 구성도(인그레스 → 프론트엔드/파일서버 → Redis 읽기·쓰기 서비스). 파일 레이아웃 규약(서비스별 디렉터리)
- 실습: 프론트엔드 Deployment + Redis StatefulSet + 파일 서버 + Service 4종 + Ingress를 순서대로 배포 → 동작 확인 → 같은 것을 Helm 차트로 묶고 values로 환경 분기
- 명령: `apply -k`, `helm create/lint/template/install/upgrade/uninstall`, `helm get values`
- 책 연결: 1.7~1.11, 1.11 서비스 배포 모범 사례
- 산출물: `labs/k8s/journal/` 매니페스트 일습 + `labs/charts/journal/` 차트 + `labs/scripts/rebuild.sh`. M15~M18이 이 앱을 대상으로 삼는다. M15~M27은 `k8s/journal/`을 정본으로 고치고 차트는 M28이 따라잡는다

---

# Part 3. 운영 기초 (M15~M18) — 중반

## M15. 프로브와 파드 라이프사이클
- 이론: liveness(살아있나 — 아니면 재시작) / readiness(트래픽 받을 준비 — 아니면 엔드포인트 제외) / startup(느린 시작 보호) 역할 분담. preStop 훅과 커넥션 드레이닝, `terminationGracePeriodSeconds`, SIGTERM
- 실습(3단 비교 — M10에서 잰 실패 17건이 출발점이다): ① readiness를 떼고 롤아웃해 실패가 몇 배로 뛰는지 측정 → ② readiness를 복구해 17건 수준으로 되돌림 → ③ `preStop sleep 5` + `terminationGracePeriodSeconds`를 더해 0건. 그다음 liveness 임계값을 일부러 낮춰 재시작 루프(CrashLoop) 재현, startupProbe로 느린 시작 보호
- 주의: readiness만으로는 0이 되지 않는다. M10의 17건은 시작(readiness)이 아니라 **종료 창**의 문제다 — 엔드포인트에서 빠지는 것과 프로세스가 죽는 것이 동시에 일어나지 않는다. 이 구분이 M15의 핵심이다
- 사전 준비: 부하 루프 도구. M10의 `curlbox`는 M14 6단계에서 삭제되므로 M15 1단계에서 다시 만든다(`sleep infinity`로)
- 명령: `apply`, `get po -w`, `describe po`(Events의 Unhealthy), `logs --previous`
- 책 연결: 5.7 롤링 업데이트의 두 안전장치
- 검증: 부하 루프 중 롤아웃해도 실패 요청 0

## M16. 리소스, QoS, 스케줄링
- 이론: 스케줄러 2단계(프레디킷·우선순위), requests가 스케줄링을 결정하고 limits가 런타임을 제한한다. QoS 3등급과 축출 순서, PDB, 네임스페이스 단위 통제(ResourceQuota·LimitRange)
- 실습: requests 과다로 Pending 재현 → `describe`의 이벤트로 원인 읽기 → nodeSelector·affinity·anti-affinity로 배치 제어 → taint/toleration → topologySpreadConstraints로 노드 분산 → ResourceQuota 초과로 생성 거부 → PDB 걸고 `drain` 시도
- 명령: `describe node`, `top node/pod`, `taint`, `cordon/drain/uncordon`, `get quota/limitrange/pdb`
- 책 연결: 8.1~8.3.6
- 재사용: `docs/chapter8`, `docs/쿠배창모-리소스관리.pdf`

## M17. 오토스케일링
- 이론: 3계층(파드 수평 HPA / 파드 수직 VPA / 노드 클러스터 오토스케일러·Karpenter). HPA가 requests 기준으로 계산하는 구조, 안정화 윈도우와 진동
- 실습: metrics-server 확인(M01에서 설치) → 앱에 `requests`가 있어야 HPA가 계산한다는 것부터(M16 산출물) → HPA(CPU) 생성 → k6로 부하 → 스케일 아웃·인 관찰 → behavior로 스케일인 지연 조정 → 커스텀 메트릭 HPA(프로메테우스 어댑터) 개요 실습
- 명령: `autoscale deploy`, `get hpa -w`, `describe hpa`, `top pod`
- 책 연결: 8.3.7~8.3.11
- 검증: 부하 종료 후 안정화 윈도우만큼 기다렸다가 축소되는 것 확인

## M18. 스토리지와 스테이트풀 애플리케이션
- 이론: 볼륨과 볼륨 마운트, PV/PVC/StorageClass 3자 관계, 동적 프로비저닝, reclaim policy, CSI. StatefulSet이 Deployment와 다른 3가지(안정 네트워크 ID·순서 보장·PVC 템플릿), 오퍼레이터로 넘어가는 경계
- 실습: PVC 생성 → 파드에 마운트 → 파드 삭제 후 데이터 생존 확인 → StatefulSet으로 3노드 DB → 헤드리스 서비스로 `pod-0.svc` 접근 → 스케일 다운 시 PVC가 남는 것 확인
- 일부러 실패: 볼륨 확장. kind 기본 `local-path` 스토리지클래스는 `allowVolumeExpansion: false`라 PVC 확장이 거부된다. 거부 메시지를 보여준 뒤 "확장은 스토리지클래스가 허용해야 가능하다"로 정리한다
- 명령: `get pv,pvc,sc`, `describe pvc`, `exec -- df -h`, `delete sts --cascade=orphan`
- 책 연결: 16장 전체
- 재사용: `docs/k8s-volumn.html`, `docs/이미지참고/StatefulSet-PVC-PV-StorageClass구조.png`

---

# Part 4. 관측 (M19~M22) — 중반 · **책 3장 검증·확장 대상**

책 3장(모니터링과 로깅) 12개 절 전부를 다루되, 책에 없는 실행 결과와 실패 재현을 채운다.
기존 `docs/chapter3/ch03-monitoring-logging.html`은 이론 서술이 완성돼 있고 코드 블록이
10개뿐이며 실행 결과가 없다 — 이 파트가 그 격차를 메운다. 상세 계획은 CLAUDE.md
"chapter3·chapter20 검증·확장 계획" 절 참조.

## M19. 메트릭 파이프라인과 프로메테우스 스택
- 이론: 3.1 메트릭 vs 로그 / 3.2 블랙박스·화이트박스, 풀·푸시 / 3.4 cAdvisor·metrics-server·kube-state-metrics 3자 구분(무엇을, 어디서, 얼마나 오래) / 3.6 툴 선택 근거 / 3.7 프로메테우스 풀 모델과 익스포터
- 실습: `kubectl top`이 왜 되는지(metrics-server) → **두 번째 앱 `order-api`(Spring Boot) 배포** — 언어가 다른 앱이 섞인 클러스터가 이 파트의 실습장이다 → kube-prometheus-stack 헬름 설치 → 타깃 목록 확인 → cAdvisor·KSM 메트릭을 직접 질의해 3자 차이를 눈으로 → 스크레이프 주기·보존 기간 값 확인
- 명령: `helm repo add/update`, `helm install -f values.yaml`, `get servicemonitor,prometheus`, `port-forward svc/...-prometheus 9090`, `curl /api/v1/targets`
- 검증: `curl -s localhost:9090/api/v1/targets | jq '[.data.activeTargets[]|select(.health=="up")]|length'` 가 타깃 수와 같다

## M20. PromQL과 애플리케이션 계측
- 이론: 3.3 USE·RED·4 골든 시그널의 계보와 역할 분담 / 3.5 계층적 모니터링(노드→컴포넌트→애드온→앱)
- 실습: `order-api`는 Micrometer로 `/actuator/prometheus`를, `journal-api`는 `prom-client`로 `/metrics`를 노출한다 — 같은 RED 지표를 언어가 다른 두 앱에서 뽑아 이름 규약을 맞춘다 → ServiceMonitor 라벨 3겹 연결 → 일부러 라벨 어긋뜨려 타깃 누락 재현·복구 → RED 질의 6개 작성 → 히스토그램 분위수와 카디널리티 비용
- 명령: `curl /actuator/prometheus`, PromQL(`rate`, `sum by`, `histogram_quantile`), `promtool check rules`
- 검증: 앱 타깃 up == 1, P99 패널에 데이터

## M21. 대시보드와 알림
- 이론: 3.7 TIP "그래프의 장벽" — 대시보드 과잉 경고 / 3.11 SLO 기반 알림, 임계치 표준화, 알림 피로
- 실습: Grafana 대시보드를 ConfigMap 사이드카로 코드화 → PrometheusRule 4개 작성 → ChaosController로 지연·에러 유발 → pending → firing → resolved 상태 전이 관찰 → Alertmanager 라우팅·억제
- 명령: `get prometheusrule`, `amtool`(또는 UI), `port-forward svc/...-alertmanager 9093`
- 검증: 알림이 발화하고 원인 제거 후 자동 해소

## M22. 로깅
- 이론: 3.8 로그 수집 대상 4종(노드·컨트롤플레인·감사·앱), stdout 원칙 vs 사이드카, 보존 기간 30~45일 / 3.9 툴 선택 / 3.10 로키 스택
- 실습: `kubectl logs`의 한계(파드가 사라지면 로그도 사라진다) 재현 → Loki + Alloy 설치 → LogQL로 조회 → 로그·메트릭 상관(같은 시각의 알림과 로그 연결) → 라벨 카디널리티 폭발 실험
- 명령: `logs --previous`, `helm install loki/alloy`, LogQL(`{namespace=""} |= "ERROR"`)
- 정정 교육 포인트: 검색하면 나오는 Promtail·`loki-stack` 차트는 쓰지 않는다(2026-03 EOL)

---

# Part 5. 보안과 정책 (M23~M27) — 중후반

## M23. RBAC와 인가
- 이론: 4.4 RBAC 기초(Role/ClusterRole/Binding, 동사와 리소스), 17.2 인가 모듈 순서(Node·RBAC·Webhook), 최소 권한
- 실습: 개발자용 ServiceAccount 발급 → 네임스페이스 한정 Role → kubeconfig 만들어 실제로 권한 밖 명령이 거부되는 것 확인 → `can-i --list` → aggregated ClusterRole
- 명령: `create sa/role/rolebinding`, `auth can-i --as=`, `create token`, `describe clusterrole`
- 정정: K8s 1.24+에서 SA 토큰 시크릿 자동 생성 제거 — `secrets[0].name` 조회 명령은 동작하지 않는다. `kubectl create token` 사용

## M24. 파드와 컨테이너 보안
- 이론: 10.1 파드 시큐리티 어드미션 3수준(privileged/baseline/restricted)과 3모드(enforce/audit/warn), 10.2 RuntimeClass와 워크로드 격리(gVisor·Kata), 19.3 seccomp·AppArmor·SELinux
- 실습: 네임스페이스에 `restricted` 라벨 → 기존 파드가 거부되는 것 확인 → securityContext(runAsNonRoot, readOnlyRootFilesystem, drop ALL) 채워 통과 → seccomp 프로파일 적용 → distroless 이미지로 교체
- 명령: `label ns pod-security.kubernetes.io/enforce=restricted`, `apply`(거부 메시지 읽기), `get po -o jsonpath=...securityContext`

## M25. 네트워크 정책과 서비스 메시
- 이론: 9.4 기본 허용을 기본 거부로, 정책은 CNI가 집행한다 / 9.6 서비스 메시가 주는 것과 대가(사이드카 vs 앰비언트)
- 실습: 기본 상태에서 모든 파드가 서로 통신되는 것 확인 → default-deny 적용 → 필요한 경로만 개방 → DNS 차단 사고 재현(egress 정책의 흔한 실수) → 메시는 개요 시연
- 명령: `apply -f netpol.yaml`, `run -it --rm ... -- curl`, `get netpol`
- 재사용: `docs/cilium-slides.html`, `docs/이미지참고/노드간통신-CNI.svg`

## M26. 어드미션 컨트롤과 정책 엔진
- 이론: 17.1 요청 파이프라인(인증→인가→어드미션→etcd), 뮤테이팅·밸리데이팅 순서 / 11장 게이트키퍼 개념(제약조건 템플릿·제약조건·감사)과 현재의 대안(ValidatingAdmissionPolicy CEL 내장, Kyverno)
- 실습: 내장 ValidatingAdmissionPolicy로 "latest 태그 금지" 정책 작성 → warn → enforce 단계 승격 → 기존 위반 리소스 감사 → 정책 테스트 → 서명되지 않은 이미지를 막는 정책(M07에서 예고한 서명 검증의 집행 지점)
- 명령: `apply -f vap.yaml`, `get validatingadmissionpolicy,validatingadmissionpolicybinding`, 거부 메시지 확인
- 책 연결: 11.5 집행 액션과 감사

## M27. 클러스터 보안 태세
- 이론: 19.1 etcd 접근·인증·인가·TLS·kubelet과 클라우드 메타데이터·감사 로깅 / 19.4 넌루트·무배포 컨테이너, 취약점 스캔, 코드 저장소 보안
- 실습: 감사 정책 켜고 로그 읽기 → 메타데이터 접근 차단 실습 → 이미지 스캔을 M07과 이어 CI에 배치할 준비 → CIS 성격 진단 도구 1종 실행 후 상위 지적 3개 수정
- 재사용: `docs/01-쿠버네티스_보안_발표.html`, `docs/chapter19`

---

# Part 6. 배포 자동화 (M28~M32) — 후반

## M28. Helm과 Kustomize
- 이론: 템플릿(Helm) vs 오버레이(Kustomize) 선택 기준. Helm 4 변경점과 Helm 3 사용자를 위한 대응표. 차트도 테스트 대상이다(`helm lint` — 책 5.3)
- 실습: M14 차트를 dev/prod values로 분기 → `helm diff`로 변경 미리보기 → `helm test` → 같은 앱을 Kustomize 오버레이로 재구성 → 둘을 함께 쓰는 지점
- 명령: `helm lint/template/diff/upgrade --atomic/rollback/history`, `kustomize build`, `kubectl apply -k`, `kubectl diff -k`

## M29. CI — 빌드·테스트·이미지
- 이론: 5.1 앱 코드와 구성 코드 한 저장소, 5.2 작은 커밋과 빠른 피드백, 5.3 **테스트가 실패하면 빌드도 실패**, 5.5 latest 금지
- 실습: GitHub Actions 워크플로 작성 → 단위 테스트 → 이미지 빌드·태깅(깃 SHA) → 매니페스트 검증(`kubectl apply --dry-run=server`, `helm lint`, `kubeconform`) → 취약점 스캔 게이트 → SBOM 생성과 이미지 서명(M07에서 개념만 봤던 것을 여기서 파이프라인에 넣는다)
- 정정: 책의 drone.io 예제는 쓰지 않는다(책 2.4.2가 스스로 GitHub Actions를 언급). cluster-admin 남발도 재현하지 않는다

## M30. 배포 전략과 롤아웃 판정
- 이론: 5.7 롤링/블루그린/카나리 각각의 대가, 카나리의 "판단 메트릭" — M20에서 만든 RED 지표가 그것이다. 6장 버저닝·릴리스 레이블 규약
- 실습: 롤링 재확인 → 블루/그린 전환을 Service 셀렉터 교체로 → Argo Rollouts로 카나리 10%→50%→100% 자동 승격 → 에러율 임계 초과 시 자동 롤백
- 명령: `kubectl argo rollouts get rollout --watch`, `promote`, `abort`
- 검증: 의도적 불량 버전이 자동 롤백된다

## M31. GitOps
- 이론: 18.1~18.3 깃옵스 4원칙, 풀 기반이 푸시 기반과 다른 점, 저장소 구조 전략 / 18.4 시크릿 관리 스펙트럼(SOPS·External Secrets·Sealed Secrets)
- 실습: Argo CD 설치 (Flux 도 같은 원리다 — 이 교재는 Argo CD 로 검증했다) → 앱 저장소 연결 → 커밋으로 배포 → 클러스터에서 수동 변경 후 드리프트 자동 복구 관찰 → SOPS로 시크릿 암호화 커밋
- 명령: `kubectl apply -f application.yaml`, `argocd.argoproj.io/refresh` 주석, `kubectl edit`(드리프트 유발) 후 복구 관찰
- 재사용: `docs/chapter18`, `docs/kubenetes/day13`

## M32. 글로벌 롤아웃과 사고 대응
- 이론: 7.1~7.5 이미지 분산, 배포 파라미터화, 사전 롤아웃 검사, 카나리 리전, 리전 타입 식별, 문제 발생 시 대처
- 실습: 클러스터 2개(kind 두 개)로 리전 흉내 → 카나리 리전 먼저 배포 → 판정 후 확산 → 롤백 플레이북 작성·연습
- 산출물: 롤아웃 체크리스트와 사고 대응 러너북

---

# Part 7. 확장 (M33~M35) — 후반

## M33. CRD와 오퍼레이터 구현
- 이론: 21.1~21.7 API 오브젝트·리소스·그룹·버전·카인드, 조정(reconcile) 루프, 검증, 오퍼레이터 라이프사이클과 버전 업그레이드
- 실습: CRD 정의(스키마 검증·printer column·status 서브리소스) → 수동 조정 루프를 셸로 흉내 → kubebuilder로 컨트롤러 뼈대 생성 → reconcile 구현 → 실행하며 이벤트·상태 확인
- 명령: `kubebuilder init/create api`, `make manifests install run`, `kubectl get <crd> -o yaml`
- 재사용: `docs/chapter21`

## M34. 멀티클러스터와 외부 서비스 연동
- 이론: 12.1~12.7 멀티클러스터의 이유와 설계 문제, 깃옵스 기반 관리 패턴 / 13.1~13.3 서비스 임포트(셀렉터리스 서비스·CNAME·액티브 컨트롤러), 익스포트, MCS API
- 실습: 셀렉터리스 Service + EndpointSlice 수동 작성으로 클러스터 밖 DB 연결 → ExternalName → 내부 로드밸런서로 익스포트 → 두 kind 클러스터 간 서비스 공유 개념 확인

## M35. 플랫폼 패턴과 ML 워크로드
- 이론: 15장 고수준 추상화(감싸기 vs 확장), 확장 지점 지도 / 14장 ML 워크플로, 특수 하드웨어, DRA와 디바이스 플러그인, 분산 훈련
- 실습: Job·CronJob·Indexed Job으로 배치 훈련 흉내 → 리소스 제약과 재시도 정책 → 확장 지점 요약 실습(CRD·웹훅·스케줄러 확장·CSI 중 어디를 쓸지 판단 연습)

---

# Part 8. 검증 (M36~M38) — 후반 · **책 20장 검증·확장 대상**

`docs/chapter20/ch20-chaos-load-experiment.html`은 코드 블록이 하나도 없는 순수 이론
문서다. 이 파트가 20장 3개 절 전부에 실행 가능한 실습을 채운다.

## M36. 카오스 테스팅
- 이론: 20.1.1 목표 / 20.1.2 전제 조건(관측 전략 + 자동 복구) / 20.1.3 통신 카오스 / 20.1.4 작동 카오스 / 20.1.5 퍼즈 테스팅. 게임 데이 4단계(가설→이벤트→대조→판정), 폭발 반경 최소화. 스테이징의 한계 6가지
- 실습 3단계 상승:
  1. 수동: `kubectl delete pod`로 파드 1개 종료. M21 대시보드로 판정
  2. 도구: Chaos Mesh v2.8.4 설치 → PodChaos(파드 킬) → NetworkChaos(지연·패킷 손실 — 20.1.3 통신 카오스) → StressChaos(CPU·메모리 — 20.1.4 작동 카오스) → 스케줄 실험과 자동 롤백
  3. 앱 수준: ChaosController로 지연·에러 주입, 알림 발화 관찰
  퍼즈 테스팅은 API 엔드포인트에 무작위 입력을 넣어 500이 나오는 지점을 찾는 소규모 실습으로 구성
- 산출물: 게임 데이 실험 시트(가설·정상 상태 정의·주입·판정·결론), 실험 매니페스트
- 정정: 책의 Chaos Toolkit은 2024-04 이후 릴리스 없음 → Chaos Mesh로 교체. 책은 experiment.json 내용을 싣지 않았으므로 실험 정의를 직접 작성한다

## M37. 로드 테스팅
- 이론: 20.2.1 목표(용량 산정·병목 발견) / 20.2.2 전제 조건 / 20.2.3 실제와 가까운 트래픽 생성(단일 엔드포인트 반복의 함정) / 20.2.4~20.2.5 튜닝
- 실습: k6 시나리오 작성(램프업·정상·스파이크, 여러 엔드포인트 가중치) → 베이스라인 측정 → 병목 식별(CPU 스로틀링 vs 커넥션 풀 vs GC) → 리소스 limits·HPA·풀 크기 조정 후 재측정 → 전후 비교표
- 명령: `k6 run`, `kubectl top pod`, PromQL로 스로틀링(`container_cpu_cfs_throttled_seconds_total`) 확인
- 검증: 같은 부하에서 P99가 개선된 수치로 기록된다

## M38. 실험과 최종 캡스톤
- 이론: 20.3.1~20.3.3 실험의 목표·전제·구축. A/B 테스트와 기능 플래그, 관측이 실험 판정의 도구인 이유
- 실습: 기능 플래그로 두 구현을 나눠 배포 → 메트릭으로 판정 → 실험 종료·정리
- 캡스톤: 클러스터를 지우고 M01부터 통주. 강사가 3개 장애를 심어두고 수강생이 대시보드·로그·이벤트만으로 원인 규명. 제한 시간 90분
- 산출물: 통주 스크립트, 장애 시나리오 3종과 정답지

---

## 진행 방식

| 형태 | 배치 | 회당 |
|---|---|---|
| 집중 과정 | 20회 | 3시간 |
| 주 2회 스터디 | 20주 | 2시간 + 과제 |
| 자습 | 38일 | 1~1.5시간 (M14만 2일) |

집중 과정이 19회가 아니라 **20회**인 이유는 M14 때문이다. M14는 매니페스트 일습과
Helm 차트 작성을 한 모듈에 담아 다른 모듈의 두 배(135분)이므로 **단독 회차**로 잡는다.
나머지는 2개씩 묶되, 후반 파트에서 각각 120분을 넘는 모듈(M30·M32·M33·M36·M37)은
같은 회차에 묶지 않는다.

각 모듈은 앞 모듈의 산출물을 입력으로 받는다. 건너뛰면 다음 모듈의 사전 조건이 깨지므로
모듈 첫머리의 "사전 조건" 블록에 필요한 산출물을 명시한다.

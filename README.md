# 도커 & 쿠버네티스 — 이론과 따라하기

38개 모듈, 8개 파트, 약 55시간. 브라우저로 바로 열리는 단일 파일 HTML 교안이다.

**문서의 모든 출력은 실제로 실행해서 얻은 것이다.** 3노드 kind 클러스터(Kubernetes 1.37.0)에서
명령을 돌리고 화면에 나온 것을 그대로 옮겼다. 지어낸 출력은 없다.

```
git clone https://github.com/claude-code-expert/kubernetes.git
cd kubernetes
open course/index.html          # 리눅스는 xdg-open
```

GitHub 웹에서는 HTML이 소스로 보인다. 내려받아 브라우저로 여는 편이 낫다.
시작 지점은 [`course/index.html`](course/index.html) — 로드맵과 버전 매트릭스가 있다.

---

## 이 교재가 다른 점

**실패가 본문이다.** 모든 모듈에 "일부러 실패시키기" 절이 있다. 프로브 임계값을 잘못
잡아 파드가 계속 죽는 것, 라벨 한 글자가 틀려 프로메테우스 타깃이 안 잡히는 것,
하이픈 하나로 네트워크 정책이 네임스페이스를 통째로 여는 것 — 60여 건을 재현하고
에러 메시지를 그대로 실은 뒤 고친다. 성공하는 절차는 공식 문서에 있고,
**무엇이 어떻게 틀어지는지는 겪어야 안다.**

**체크포인트가 판정 가능하다.** "이해했다" 같은 항목을 쓰지 않는다. `명령 + 기대값`
한 쌍으로만 쓴다.

```
kubectl -n journal get deploy journal-api -o jsonpath='{.status.readyReplicas}'  →  3
curl -s -o /dev/null -w '%{http_code}' -H 'Host: journal.local' localhost:18080/  →  200
```

**버전을 고정한다.** 버전을 적지 않은 실습 문서는 반년이면 못 쓴다. 모든 버전에
확인일을 붙이고, 낡은 도구는 이름을 박아 정정한다 — Promtail(2026-03 EOL) 대신 Alloy,
Chaos Toolkit(2024-04 이후 릴리스 없음) 대신 Chaos Mesh.

**앞 모듈의 산출물이 다음 모듈의 입력이다.** 건너뛰면 사전 조건이 깨진다.
각 모듈 첫머리의 "사전 조건" 블록이 무엇이 있어야 하는지 파일 경로로 알려 준다.

---

## 난이도 5단계

단계는 파트 경계와 일치한다. 시간은 읽기 + 명령 실행 + 대기(롤아웃·분석·부하)를 더해
산정한 값이고 숙련도에 따라 ±30% 차이가 난다.

| 단계 | 모듈 | 회당 평균 | 명령의 성격 |
|---|---|---|---|
| 초반 | M01~M07 | 55분 | 한 줄 명령으로 만들고 눈으로 확인 |
| 초반→중반 | M08~M14 | 70분 | 쿠버네티스 오브젝트를 만들고 YAML로 다시 쓴다 |
| 중반 | M15~M22 | 90분 | 선언형으로 고치고 **실패를 재현**한다 |
| 중후반 | M23~M27 | 95분 | 권한·정책·감사로 **사람이 못 하게** 막는다 |
| 후반 | M28~M38 | 115분 | 사람이 apply 하지 않는다. 파이프라인·정책·실험이 대신한다 |

같은 주제를 세 번 만난다. 배포를 예로 들면 M08에서 `kubectl create deployment` 한 줄로
만들고, M10에서 YAML로 다시 써 `rollout undo`까지 하고, M30에서는 아무도 명령을 치지
않는다 — 카나리가 20%로 나가고 M20에서 만든 지표가 임계를 넘으면 자동으로 되돌아간다.

---

## 모듈

### Part 1. 도커 (M01~M07)

| | 모듈 | 시간 |
|---|---|---|
| M01 | [환경 구축과 버전 고정](course/m01-setup-environment.html) | 50분 |
| M02 | [컨테이너는 프로세스다](course/m02-docker-container-basics.html) | 50분 |
| M03 | [이미지와 레이어](course/m03-docker-images-layers.html) | 40분 |
| M04 | [Dockerfile — 빌드와 최적화](course/m04-docker-dockerfile-build.html) | 65분 |
| M05 | [데이터와 네트워크](course/m05-docker-data-network.html) | 50분 |
| M06 | [Compose로 다중 서비스](course/m06-docker-compose.html) | 60분 |
| M07 | [레지스트리와 이미지 공급망](course/m07-docker-registry-supplychain.html) | 60분 |

### Part 2. 쿠버네티스 코어 (M08~M14)

| | 모듈 | 시간 |
|---|---|---|
| M08 | [클러스터 구조와 첫 배포](course/m08-k8s-cluster-first-deploy.html) | 60분 |
| M09 | [파드 · 레이블 · 네임스페이스](course/m09-k8s-pod-label-namespace.html) | 60분 |
| M10 | [디플로이먼트와 롤아웃](course/m10-k8s-deployment-rollout.html) | 60분 |
| M11 | [서비스와 클러스터 네트워크](course/m11-k8s-service-network.html) | 60분 |
| M12 | [인그레스와 Gateway API](course/m12-k8s-ingress-gateway.html) | 75분 |
| M13 | [컨피그맵과 시크릿](course/m13-k8s-configmap-secret.html) | 50분 |
| M14 | [종합 — 저널 애플리케이션과 Helm](course/m14-k8s-journal-app-helm.html) | **135분** |

M14는 다른 모듈의 두 배다. 매니페스트 일습과 헬름 차트 작성이 한 모듈에 들어 있어
**단독 회차로 잡는다.** 문서 안에 끊는 지점을 표시해 두었다.

### Part 3. 운영 기초 (M15~M18)

| | 모듈 | 시간 |
|---|---|---|
| M15 | [프로브와 파드 라이프사이클](course/m15-k8s-probes-lifecycle.html) | 75분 |
| M16 | [리소스 · QoS · 스케줄링](course/m16-k8s-resources-scheduling.html) | 100분 |
| M17 | [오토스케일링](course/m17-k8s-autoscaling.html) | 80분 |
| M18 | [스토리지와 스테이트풀 애플리케이션](course/m18-k8s-storage-stateful.html) | 80분 |

### Part 4. 관측 (M19~M22)

| | 모듈 | 시간 |
|---|---|---|
| M19 | [메트릭 파이프라인과 프로메테우스 스택](course/m19-k8s-metrics-pipeline.html) | 95분 |
| M20 | [PromQL과 애플리케이션 계측](course/m20-k8s-promql-instrumentation.html) | 95분 |
| M21 | [대시보드와 알림](course/m21-k8s-dashboard-alerting.html) | 90분 |
| M22 | [로깅](course/m22-k8s-logging-loki.html) | 100분 |

### Part 5. 보안과 정책 (M23~M27)

| | 모듈 | 시간 |
|---|---|---|
| M23 | [RBAC과 인가](course/m23-k8s-rbac-authz.html) | 80분 |
| M24 | [파드와 컨테이너 보안](course/m24-k8s-pod-container-security.html) | 90분 |
| M25 | [네트워크 정책과 서비스 메시](course/m25-k8s-networkpolicy-mesh.html) | 95분 |
| M26 | [어드미션 컨트롤과 정책 엔진](course/m26-k8s-admission-policy.html) | 100분 |
| M27 | [클러스터 보안 태세](course/m27-k8s-cluster-security-posture.html) | 110분 |

### Part 6. 배포 자동화 (M28~M32)

| | 모듈 | 시간 |
|---|---|---|
| M28 | [Helm과 Kustomize](course/m28-k8s-helm-kustomize.html) | 110분 |
| M29 | [CI — 빌드·테스트·이미지](course/m29-k8s-ci-pipeline.html) | 100분 |
| M30 | [배포 전략과 롤아웃 판정](course/m30-k8s-deploy-strategies.html) | 120분 |
| M31 | [GitOps](course/m31-k8s-gitops.html) | 110분 |
| M32 | [글로벌 롤아웃과 사고 대응](course/m32-k8s-global-rollout.html) | 125분 |

### Part 7. 확장 (M33~M35)

| | 모듈 | 시간 |
|---|---|---|
| M33 | [CRD와 오퍼레이터 구현](course/m33-k8s-crd-operator.html) | 125분 |
| M34 | [멀티클러스터와 외부 서비스 연동](course/m34-k8s-multicluster-external.html) | 100분 |
| M35 | [플랫폼 패턴과 ML 워크로드](course/m35-k8s-platform-ml.html) | 100분 |

### Part 8. 검증 (M36~M38)

| | 모듈 | 시간 |
|---|---|---|
| M36 | [카오스 테스팅](course/m36-k8s-chaos-testing.html) | 140분 |
| M37 | [로드 테스팅](course/m37-k8s-load-testing.html) | 120분 |
| M38 | [실험과 최종 캡스톤](course/m38-k8s-capstone.html) | 캡스톤 90분 |

---

## 실습 환경

| 구성요소 | 버전 | 비고 |
|---|---|---|
| Kubernetes | 1.37.0 | kind 노드 이미지는 `@sha256` 다이제스트까지 고정 |
| kind | v0.33.0 | 노드 3개 (control-plane 1 + worker 2) |
| Docker Engine | 29.x | |
| Helm | 4.2.4 | Helm 3의 `--atomic` 폐기 등 차이는 M28에서 다룬다 |
| kube-prometheus-stack | 89.2.2 | Prometheus Operator v0.93.1 |
| Loki + Alloy | 3.6.12 / v1.19.2 | Promtail은 쓰지 않는다 (2026-03 EOL) |
| Argo Rollouts / Argo CD | v1.10.0 / v3.5.2 | M30 / M31 |
| Chaos Mesh | 2.8.4 | kind에서는 `chaosDaemon.runtime: containerd` 필요 |
| k6 | v2.2.0 | M17 · M37 |

메모리 8GiB 이상을 도커에 할당한다. M32·M34는 kind 클러스터를 하나 더 띄운다.

**실습 앱은 두 개다.** `journal-api`(Node 22 · Express 5 · TypeScript)가 M04~M18의 대상이고,
`order-api`(Spring Boot 4.1 · JDK 21)가 M19부터 합류한다. 실제 클러스터에는 언어가 다른 앱이
섞여 있고 스크레이프 설정이 앱마다 다르다는 것 자체가 관측 파트의 교재다.

---

## 저장소 구조

```
course/
  index.html              로드맵 · 난이도 · 버전 매트릭스
  m01~m38-*.html          교안 38편
  figures/                모듈별 SVG 도판
  labs/                   실습 파일 170개 — 모듈이 아니라 역할로 나눈다
    infra/                kind 클러스터 정의 · 감사 정책
    apps/                 journal-api · order-api · gitserver · compose
    k8s/                  매니페스트 (journal · netpol · policy · crd · batch · gitops · multi …)
    charts/journal/       헬름 차트
    monitoring/           kube-prometheus-stack · Loki · Alloy values, 대시보드 JSON
    chaos/                Chaos Mesh 실험 · 게임 데이 시트 · 장애 시나리오 3종
    operator/journalsite/ kubebuilder 로 만든 오퍼레이터 (타입 · 조정 함수)
    scripts/              도구 16종
CURRICULUM.md             커리큘럼 정본 — 모듈 정의와 버전 매트릭스
CLAUDE.md                 제작 규약 — 교안 골격 · 문체 · HTML 규약
docs/                     기존 자산 (책 21개 장 대응 HTML, 관측성 스터디, 슬라이드)
.github/workflows/ci.yaml 테스트 · 스캔 · 차트 검사 · e2e 파이프라인
```

### 자주 쓰는 스크립트

| 스크립트 | 하는 일 |
|---|---|
| `scripts/preflight.sh` | 실습 전 환경 점검. 실패하면 종료 코드 1 |
| `scripts/rebuild.sh` | 빈 클러스터에서 M14 시점까지 복구. 실습이 꼬였을 때의 탈출구 |
| `scripts/capstone-check.sh` | **49개 항목 통주 점검.** 파일과 클러스터 상태를 함께 본다 |
| `scripts/ci.sh` | 로컬 파이프라인 — 타입 검사 · 테스트 · 이미지 · 스캔 · 차트 · 어드미션 |
| `scripts/loadgen.sh` | 부하와 응답 코드 집계 (M15 · M36) |
| `scripts/k6-capacity.js` | 램프업 · 정상 · 스파이크 · 회복 시나리오 (M37) |
| `scripts/incident.sh` | 캡스톤 장애 주입·정리 (M38, 강사용) |
| `scripts/policy-audit.sh` | 이미 배포된 리소스 중 정책 위반 찾기 (M26) |
| `scripts/region-check.sh` | 리전 건강 판정. 종료 코드가 확산의 관문 (M32) |
| `scripts/fuzz-api.sh` | API 퍼즈 — 500이 나오는 지점을 찾는다 (M36) |

---

## 통주 점검

전체가 동시에 성립하는지 한 줄로 확인한다.

```bash
bash course/labs/scripts/capstone-check.sh          # 49개 항목 전부
bash course/labs/scripts/capstone-check.sh part5    # 한 파트만
```

```
Part 3 — 안정성 (M15~M18)
  ✓ M15 프로브 3종
  ✓ M15 preStop
  ✓ M16 cpu limit 없음 (의도된 결정)
  ✓ M16 토폴로지 분산
  ...
결과
  통과 49 · 실패 0
  전부 통과 — 통주 완료
```

"없어야 할 것"도 검사한다. 누군가 안전을 위해 `cpu limit`을 걸었다면 이 점검이 잡는다 —
M37에서 그 설정 하나가 P99를 3.54ms에서 14.74초로 만드는 것을 측정했다.

---

## 진행 방식

| 형태 | 배치 | 회당 |
|---|---|---|
| 집중 과정 | 20회 | 3시간 |
| 주 2회 스터디 | 20주 | 2시간 + 과제 |
| 자습 | 38일 | 1~1.5시간 (M14만 2일) |

19회가 아니라 20회인 이유는 M14 때문이다. 후반 파트에서 120분을 넘는 모듈
(M30·M32·M33·M36·M37)도 같은 회차에 묶지 않는다.

---

## 이론 축

『쿠버네티스 창시자에게 배우는 모범 사례 2판』(한빛미디어 2024) 21개 장에 대응한다.
각 모듈의 이론 절에 장·절 번호를 밝혀 두었다.

책이 이론만 싣고 실습을 싣지 않은 두 장을 확장했다.

- **3장 모니터링과 로깅** → M19~M22. 12개 절마다 대응 실습을 붙였다
- **20장 카오스·부하** → M36~M38. 원본에 코드 블록이 하나도 없어 실험 정의를 직접 썼다

책의 낡은 실습(Promtail, `loki-stack` 차트, Chaos Toolkit, `cluster-admin` 남발 등)은
이름을 박아 정정하고, 그 격차 자체를 교육 소재로 쓴다.

---

## 라이선스와 사용

교육 목적으로 만들었다. `course/` 아래는 자유롭게 참고하되, `docs/` 의 일부 자산은
원저작물에서 가져온 것이므로 재배포 전에 출처를 확인한다.

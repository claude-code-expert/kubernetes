# 3장 모니터링과 로깅 — 발표 목차·자료 매핑 (초안)

작성 2026-09-26. 원전 `docs/pdf/kubernetes-best-practice.pdf` 3장(책 77~104쪽, PDF 전권 452쪽).
레이아웃 기준 `presentation/slide-show.html` (1280×720, kicker·h1·body·foot·notes, section-lead·expanded).
총 68장. 표기: [책] 원문 절 · [보강] 코드베이스 이론 추가 · [실습] 명령·코드 · [정정] 책 내용 갱신.

GitHub 링크 기준: `https://github.com/claude-code-expert/kubernetes/blob/main/`
실습 정본: `course/` M19~M22 (K8s 1.37.0 · kind v0.33.0 · kps 89.2.2 · Loki 차트 7.3.0 · Alloy 차트 1.12.1, 2026-09-23 재검증).
`study/` (1.36 라인)은 이론·설명 보강으로만 쓰고 명령·출력은 섞지 않는다.

## 0. 오프닝 (1~4)
| # | 제목 | 형식 | 출처 |
|---|---|---|---|
| 1 | 표지 | cover | — |
| 2 | 오늘의 질문 — "order-api가 느리다" 한 건을 메트릭→알림→로그로 좁힌다 | lead | M21 21.1, M22 22.1 도입 |
| 3 | 전체 지도 — 수집·저장·시각화·알림·로그 파이프라인 | diagram | docs/chapter3/fig03-1-pipelines.svg, 책 그림 3.1 |
| 4 | 실습 환경과 버전 (확인일 + 당일 재확인) | expanded 표 | CURRICULUM.md 매트릭스, HANDOFF.md 3절 |

## 1. 이론 — 메트릭·로그·모니터링 기법 [책 3.1~3.3] (5~11)
| # | 제목 | 형식 | 출처 |
|---|---|---|---|
| 5 | 섹션 리드 | section-lead | — |
| 6 | 메트릭은 "몇 번", 로그는 "무엇" | split cards | [책 3.1] + [보강] M22 22.1 "에러율 5.9%" |
| 7 | 폐쇄형 vs 개방형 모니터링 | compare cards | [책 3.2] "디스크가 꽉 찼다" vs "왜" |
| 8 | 파드는 VM처럼 지켜볼 수 없다 | split | [책 3.3 도입] + [보강] M19 19.1 kubectl top 순간값 한계 |
| 9 | USE 방법론 | cards | [책 3.3] 노드 네트워크 예 |
| 10 | RED와 4대 골든 시그널 | cards | [책 3.3] 프론트엔드 세 질문 |
| 11 | USE·RED는 보완, 그리고 평균의 함정 | expanded | [책 3.3] + [보강] M20 20.6·20.8 (평균 vs P99 실측) |

## 2. 개념 — 쿠버네티스 메트릭 출처 [책 3.4~3.5] (12~19)
| # | 제목 | 형식 | 출처 |
|---|---|---|---|
| 12 | 섹션 리드 | section-lead | — |
| 13 | 모니터링 대상 컴포넌트 지도 | diagram | [책 3.4], docs/이미지참고/주요구성요소.png 재도해 |
| 14 | cAdvisor — 컨테이너 메트릭의 진실 공급원 | split | [책 3.4.1] + [보강] M19 19.5 `container_*` 실측 |
| 15 | metrics-server와 Resource Metrics API | split code | [책 3.4.2] + [정정] Heapster 폐기 + [실습] `kubectl get --raw /apis/metrics.k8s.io/...` |
| 16 | Custom·External Metrics API | cards | [책 3.4.2] + [보강] M17 오토스케일링 연결 (개념만) |
| 17 | kube-state-metrics — 질문을 메트릭 이름으로 | 표 | [책 3.4.3] 질문 목록 ↔ `kube_*` 매핑 |
| 18 | 세 출처 한 장 비교 | expanded | [보강] M19 19.2, course/figures/m19-fig1-three-sources.svg |
| 19 | 무엇을 보나 — 4계층 접근 | 표 | [책 3.5] 타깃 메트릭 목록 + 대기 파드 드릴다운 |

## 3. 도구와 프로메테우스 구조 [책 3.6~3.7 전반] (20~25)
| # | 제목 | 형식 | 출처 |
|---|---|---|---|
| 20 | 섹션 리드 | section-lead | — |
| 21 | 모니터링 툴 지형과 선택 기준 | 표 | [책 3.6] + [정정] Stackdriver → Google Cloud Observability |
| 22 | 데이터 모델 — 이름 + 라벨 = 시계열 | split code | [책 3.7] exposition 예 + [보강] M20 20.2 counter·gauge·histogram |
| 23 | 풀 모델 아키텍처 | diagram | [책 그림 3.1] + [보강] M19 "풀 모델 — 왜 긁어 가는가" |
| 24 | kube-prometheus-stack 구성 6요소 + 오퍼레이터 CRD | cards | [책 3.7] + [보강] M20 20.2 ServiceMonitor·PrometheusRule |
| 25 | 관측 스택을 어디에 둘 것인가 | split | [책 TIP utility cluster·Thanos] + [보강] M19 19.8, study ch09 remote write |

## 4. 실습 ① 프로메테우스 스택 설치·사용 [책 3.7 후반] (26~36)
| # | 제목 | 형식 | 출처·링크 |
|---|---|---|---|
| 26 | 섹션 리드 | section-lead | — |
| 27 | 책 절차 vs 지금 절차 | expanded 표 | [정정] minikube→kind, stable 저장소, 버전 미고정, admin/prom-operator. docs/chapter3 note-2026 |
| 28 | 0단계 — kind 클러스터와 사전 점검 | code | course/labs/infra/kind-cluster.yaml, course/labs/scripts/preflight.sh |
| 29 | 두 번째 앱 order-api를 들여온다 | code | M19 19.3, course/labs/k8s/apps/10-order-api.yaml |
| 30 | 차트 버전 확정과 values 핵심 | split code | course/labs/monitoring/kps-values.yaml (scrapeInterval·retention·storageSpec 발췌) |
| 31 | helm install과 결과 | code + 출력 | M19 19.4 |
| 32 | 타깃 검증 + 실패: 컨트롤 플레인 타깃 6개 DOWN | split | M19 19.7 실패①, study ch04 08절 |
| 33 | 세 출처를 질의로 가른다 | code + 출력 | M19 19.5 |
| 34 | PromQL 첫 다섯 문장 | code | study ch04 10절, docs/chapter3/ch03a A.2 |
| 35 | Grafana — USE Method / Cluster 대시보드 | 스크린샷 | [책 그림 3.2] + ch03a B.1~B.2 (캡처 필요) |
| 36 | 얼마나 쌓이고 얼마나 남는가 | code + 출력 | M19 19.6 |

## 5. 실습 ② 앱 계측·ServiceMonitor·RED [책 3.12.1 보강] (37~44)
| # | 제목 | 형식 | 출처·링크 |
|---|---|---|---|
| 37 | 섹션 리드 | section-lead | — |
| 38 | 노출하는데 수집되지 않는다 (274 계열 vs 0건) | split | M19 실패②, M20 20.1 |
| 39 | ServiceMonitor 라벨 세 겹 | diagram | M20 20.2, course/figures/m20-fig1-label-chain.svg |
| 40 | 실패 먼저 — release 라벨 없이, 포트를 숫자로 | code + 출력 | M20 실패①, study ch06 05절 |
| 41 | 연결 성공과 검증 | code | course/labs/k8s/monitoring/90-servicemonitors.yaml |
| 42 | order-api 계측 — Micrometer와 커스텀 메트릭 4종 | split | study ch02 12절, study/labs/apps/order-api/ |
| 43 | RED 세 쿼리와 부하 (종료 방법 포함) | code | M20 20.5, course/labs/scripts/k6-red.js |
| 44 | 평균 뒤 P99, 히스토그램의 비용 | split | M20 20.6·실패③·20.8 |

## 6. 알림과 대시보드 [책 3.11, 3.12.3] (45~53)
| # | 제목 | 형식 | 출처·링크 |
|---|---|---|---|
| 45 | 섹션 리드 | section-lead | — |
| 46 | 알림은 양날의 검 — SLO에 닿는 것만 | lead | [책 3.11] 파드 실패 예 |
| 47 | 사람을 부를 것 vs 자동으로 고칠 것 | compare | [책 3.11] + [보강] M21 21.2 "증상에 걸고 원인으로 내려간다" |
| 48 | 임계치·정보·수신자 ↔ PrometheusRule 필드 | expanded | [책 3.11] 5분·표준화·플레이북 ↔ for·labels·annotations |
| 49 | 알림 하나의 세 가지 시간 | diagram | M21 21.2, course/figures/m21-fig1-alert-lifecycle.svg |
| 50 | 규칙 넷 — AppHighErrorRate 발췌 | code | course/labs/k8s/monitoring/91-prometheusrule.yaml |
| 51 | 발화시킨다 — pending → firing → Alertmanager | code + 출력 | M21 21.4·21.5, study ch07 08절 |
| 52 | 실패: 알림이 꺼지지 않는다 | split | M21 실패①, study ch07 09절 |
| 53 | 그래프의 장벽과 대시보드를 코드로 | split | [책 TIP] + M21 21.6·실패②, study ch05 06~07절, dashboards/study-red.json |

## 7. 로깅 [책 3.8~3.10] (54~64)
| # | 제목 | 형식 | 출처·링크 |
|---|---|---|---|
| 54 | 섹션 리드 | section-lead | — |
| 55 | 무엇을 로깅할 것인가 — 노이즈·비용·보존 | cards | [책 3.8] 30~45일, 컴플라이언스 역주 |
| 56 | 수집 대상 4종 | 표 | [책 3.8] + [정정] 도커 데몬→containerd, 컨트롤 플레인 로그 경로, 감사 로그는 M27 (course/labs/infra/audit-policy.yaml) |
| 57 | stdout 원칙 vs 사이드카 | compare | [책 3.8·3.12.2] + M22 22.2, course/labs/k8s/m09-pod-sidecar.yaml |
| 58 | 로깅 툴 지형과 호스티드 판단 | 표 | [책 3.9] |
| 59 | 책의 로키 스택 → 지금의 Loki + Alloy | expanded | [책 3.10] + [정정] loki-stack 차트, Promtail EOL 2026-03-02, alloy convert |
| 60 | Loki 설계 — 라벨은 인덱스, 본문은 청크 | diagram | M22 22.2, course/figures/m22-fig1-label-vs-line.svg, docs/chapter3/fig03-2-loki.svg |
| 61 | kubectl logs가 멈추는 곳 | code + 출력 | M22 22.3 |
| 62 | Loki·Alloy 설치 | split code | M22 22.4, course/labs/monitoring/loki-values.yaml · alloy-values.yaml (discovery→source→write 발췌) |
| 63 | LogQL로 찾는다 | code + 출력 | [책 3.10 namespace 필터] + M22 22.6, study ch08 08절 |
| 64 | 실패: 필드를 라벨로 올리면 스트림 폭발 + 메트릭↔로그 잇기 | split | M22 실패②③·22.8, study ch08 10절 |

## 결정 사항 (2026-09-26)

- 2장 개념 슬라이드에는 캡처를 넣지 않는다. 설치 직후 4장에 "세 출처를 화면으로 확인" 묶음을 둔다(B안).
- 4장 캡처 슬롯 (사용자가 설치 실습 중 제공):
  1. Prometheus Status → Target health: 수집 잡 목록(apiserver, kube-etcd, kube-scheduler, kube-controller-manager, kubelet, kube-proxy, coredns, node-exporter, kube-state-metrics)
  2. Target health: kubelet /metrics/cadvisor 타깃
  3. 터미널: kubectl get apiservices · kubectl top pod -n apps
  4. Query: container_memory_working_set_bytes{namespace="apps"} 결과 (kubectl top과 나란히)
  5. Query: kube_deployment_spec_replicas · kube_pod_status_phase
  6. Grafana: Kubernetes / Compute Resources / Pod
  7. Grafana: Node Exporter / USE Method / Node · Cluster
  8. Grafana: Kubernetes / API server · etcd · Scheduler · Controller Manager · Proxy · CoreDNS
  9. 실패 재현: requests 과다 파드 Pending → Query 결과 + kubectl describe FailedScheduling
- 캡처 불가: 커스텀·외부 메트릭 API(어댑터 없음), 애드온 메트릭(미설치)

## 결정 사항 (2026-09-26, 2차)

- 4장·5장의 결과 확인 슬라이드는 라이브 데모로 대체한다. 각 장에 "라이브 데모" 슬라이드(순서 · 명령/질의 · 기준값)를 두고, 실측 기준값은 발표자 노트에 둔다.
- 남기는 슬라이드: 용어 · 값 파일 · 실패 원인/고치기 · 코드와 노출 이름 차이 · 실패 재현 · 체크포인트.
- 캡처 슬롯은 Pending 파드 1곳만 남는다. 나머지는 라이브 화면으로 보여 준다.
- 줄이기 전 전체본: src-removed/ch03-04-full.html, src-removed/ch03-05-full.html

## 결정 사항 (2026-09-26, 3차)

- 8장(모범 사례와 정리, 책 3.12)은 발표에서 뺀다. 원고는 src-removed/ch03-08.html 에 보관. 발표는 7장 체크포인트로 끝난다.

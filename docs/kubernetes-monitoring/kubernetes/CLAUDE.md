# CLAUDE.md — 쿠버네티스 관측성 강의 자료 제작 가이드

이 저장소는 쿠버네티스 모니터링·로깅·관측성·테스팅 강의 자료를 만드는 프로젝트다.
`docs/`의 실습 시리즈 10편이 실습 축, 아래 "책 목차 3장"이 이론 축이다.
강의 자료는 이 둘을 합쳐 **이론 → 설치 → 실습 → 검증 → 다음 단계** 흐름으로 만든다.

## 저장소 구조

```
kubernetes/
├── CLAUDE.md                  이 문서
├── docs/                      실습 시리즈 (HTML 10편 + index + figures/ 도판)
│   ├── index.html             전체 로드맵·버전 매트릭스·스터디 운영안
│   ├── 00 ~ 10                단계별 실습 문서 (09 트레이싱은 의도적 미포함)
│   ├── figures/               도판 SVG/PNG (슬라이드 재사용용)
│   └── pdf/                   원전 도서 PDF (모범 사례 2판, 한빛미디어 2024)
├── analysis/                  원전 도서 3장·5장 추출 노트와 격차 분석 — 이론 파트의 정본
│   ├── 01-책3장-모니터링과-로깅-추출.md
│   ├── 02-책5장-테스팅과-카오스-추출.md
│   └── 03-책-docs-격차와-강의-설계.md   책↔docs 정정 목록, M8 설계, 발표자료 구성
├── lectures/                  강의 모듈 m1~m8 (이론 + 실습 통합본, 초안 완료)
├── slides/                    발표자료 (수강생 배포물 — 메타·출처 표기 금지)
│   ├── 발표자료-쿠버네티스-관측성.html   따라하기 실습 강의 본문 (M1~M8 전문)
│   └── figures/               archify 도판 5종 (json 정의 + 인터랙티브 html + 정적 png)
└── labs/                      실습 파일 (docs 원문에서 추출, 완료)
    ├── README.md              사용법 — cp -R labs ~/k8s-observability 로 시작
    ├── preflight.sh · rebuild.sh · infra/kind-cluster.yaml
    ├── apps/                  order-api · gateway 소스, redeploy.sh, chaos/
    ├── k8s/                   네임스페이스·Deployment·Service, monitoring/ 매니페스트
    └── monitoring/            헬름 값 파일 3종 + dashboards/ JSON 2종
```

labs/ 파일은 docs 코드 블록의 원문 추출본이다. 값 파일은 헬름용(monitoring/),
매니페스트는 kubectl용(k8s/)으로 나뉘며 rebuild.sh가 이 경로를 참조한다 —
구조를 옮기면 스크립트가 깨진다. 메인 클래스 2개와 settings.gradle 2개만
docs에 전문이 없어 start.spring.io 표준 최소형으로 보충했다.
M8 카오스 실습 도구는 Chaos Mesh v2.8.2로 확정 (책의 Chaos Toolkit은 2024-04 이후
릴리스 없음 — analysis/03 정정 목록 참조).

## 이론 축 — 책 목차 3장 (모니터링과 로깅)

강의 이론 파트는 이 목차를 골격으로 한다.

| 절 | 주제 | docs/ 대응 | 비고 |
|---|---|---|---|
| 3.1 | 메트릭 vs 로그 | 없음 | **순수 이론. 새로 써야 함** |
| 3.2 | 모니터링 기법 (블랙박스/화이트박스, 풀/푸시) | 없음 | **새로 써야 함** |
| 3.3 | 모니터링 패턴 (RED, USE, 골든 시그널) | 06 · 07에 부분 | 이론 정리 + 06 실습 연결 |
| 3.4 | 쿠버네티스 메트릭 개요 | 04에 부분 | 이론 보강 필요 |
| 3.4.1 | cAdvisor | 04 | kubelet 내장, 컨테이너 리소스 |
| 3.4.2 | 메트릭 서버 | 04 | `kubectl top`·HPA용, 저장 안 함 |
| 3.4.3 | kube-state-metrics | 04 | 오브젝트 상태를 메트릭으로 |
| 3.5 | 어떤 메트릭을 모니터링하나 | 06 · 07 | RED 질의 6개가 실습 대응물 |
| 3.6 | 모니터링 툴 비교 | 00 | 선택 근거만, 나열식 비교 금지 |
| 3.7 | 프로메테우스로 K8s 모니터링 | 04 · 06 | 실습 중심축 |
| 3.8 | 로깅 개요 | 없음 | **새로 써야 함** (stdout 수집 원리, 로그 수명) |
| 3.9 | 로깅 툴 | 08에 부분 | Loki를 고른 이유 중심 |
| 3.10 | 로키 스택 로깅 | 08 | Loki + Alloy (Promtail 아님) |
| 3.11 | 알림 | 07 | PrometheusRule 4개가 실습 대응물 |
| 3.12 | 모범 사례 | 10 | "실습 → 운영" 타협 13가지 표와 연결 |

"새로 써야 함" 절은 이론만 3쪽 넘게 쓰지 말 것. 이론은 다음 실습이
왜 그 모양인지 설명하는 데 필요한 만큼만 쓴다.

## 강의 모듈 구성 규약

모듈 하나 = 이론 절(들) + 대응 실습 단계. 모든 모듈은 같은 골격을 따른다:

1. **왜 이걸 하나** — 앞 모듈의 결과가 왜 부족한지에서 출발 (2~3문단)
2. **이론** — 책 목차 절 내용. 실습에서 마주칠 개념만
3. **설치/실습** — docs/ 해당 단계의 명령·매니페스트. 복사-실행 가능해야 함
4. **일부러 실패시키기** — 최소 1개. 라벨 불일치, 잘못된 저장소 이름 등 실제 겪을 실수를 재현하고 고친다
5. **검증** — "무엇이 보이면 성공인지" 명시 (`up == 1`, 특정 패널에 데이터 등)
6. **다음 단계 예고** — 이 모듈의 산출물이 다음 모듈의 입력이 되는 지점을 한 문단으로

권장 모듈 분할 (docs 번호 기준):

| 모듈 | 이론 (책 3장) | 실습 (docs) |
|---|---|---|
| M1. 관측성 기초와 환경 | 3.1, 3.2, 3.6 | 00 · 01 |
| M2. 계측 가능한 애플리케이션 | 3.3 (RED) | 02 · 03 |
| M3. 프로메테우스 스택 | 3.4 (cAdvisor·metrics-server·KSM), 3.7 | 04 · 05 |
| M4. 앱 메트릭과 PromQL | 3.5 | 06 |
| M5. 대시보드와 알림 | 3.11 | 07 |
| M6. 로깅 | 3.8, 3.9, 3.10 | 08 |
| M7. 운영과 모범 사례 | 3.12 | 10 |
| M8. 테스팅과 카오스 실험 | 책 5.3 · 5.7 · 5.8 · 5.9.4 | 신규 제작 (설계: analysis/03) |

M8은 책 5장(지속적 통합, 테스팅, 배포)에서 테스팅 축만 가져온 신규 모듈이다.
연결 논거는 책 5.8 — "프로덕션 테스팅은 관측 가능성이 전제 조건". M7까지 만든
관측 스택으로 카오스 실험(게임 데이 4단계)을 판정한다. 책의 이론 추출과 실습 설계
초안은 `analysis/02`, `analysis/03`에 있다. 책의 실습 명령 중 낡은 것(Promtail,
loki-stack 차트, drone.io, SA 토큰 조회 등)은 `analysis/03` 1절 정정 목록을 따른다.

## 실습 코드 규약 (apps/)

`docs/02`의 코드가 정본이다. 요약:

- **버전**: Spring Boot 4.1.0, Spring Cloud 2025.1.2 (Oakwood), JDK 21, Gradle
- **패키지**: `com.study.obs.order`, `com.study.obs.gateway`
- **order-api**: Spring MVC + Actuator. record DTO, 정적 팩토리, `ApiResponse` 래퍼,
  `GlobalExceptionHandler`. 저장은 `ConcurrentHashMap` — DB 넣지 않는다 (계측이 주제이므로)
- **gateway**: `spring-cloud-starter-gateway-server-webflux`
  (구 `spring-cloud-starter-gateway`는 2025.1에서 제거됨)
- **메트릭 노출**: `runtimeOnly 'io.micrometer:micrometer-registry-prometheus'` +
  `/actuator/prometheus`. 커스텀 메트릭 이름·태그는 docs/02 "메트릭 지도" 절이 정본 —
  06단계 PromQL과 07단계 대시보드가 이 이름에 의존하므로 임의 변경 금지
- **ChaosController**: 지연·에러 시뮬레이션 엔드포인트 유지. 07 알림 실습의 트리거

## 고정 버전 (2026-08-19 검증 기준)

| 구성요소 | 버전 | 함정 |
|---|---|---|
| Kubernetes / kind | 1.36.x / v0.32.0 | kubeadm 설정은 v1beta4 |
| kube-prometheus-stack | 차트 88.x | Operator v0.91 계열 |
| Prometheus / Grafana | 3.x / 13.x | 데이터소스는 uid로만 참조 |
| Loki | 3.7.x | 차트 저장소는 `grafana`가 아니라 **`grafana-community`** |
| 로그 수집기 | Grafana Alloy | **Promtail은 2026-03 EOL. 쓰지 말 것** |
| Spring Boot / Cloud | 4.1.0 / 2025.1.x | 게이트웨이 프로퍼티는 `spring.cloud.gateway.server.webflux.*` |

문서에 버전을 적을 때는 반드시 검증일을 함께 적고, "실습 당일 `helm search repo`로
재확인" 안내를 붙인다. 학습 자료에서 낡은 버전 숫자는 오타보다 해롭다.

## 문체 규약 — AI 냄새 제거

`docs/`의 기존 문체가 기준이다. 새 문서를 쓰기 전에 docs/ 한 편을 먼저 읽을 것.

**금지:**
- 이모지, "여러분", "~에 대해 알아보겠습니다", "자, 이제", "간단히 말해서"
- "다양한", "강력한", "핵심적인 역할", "~하는 것이 좋습니다" 류의 빈 수식
- "결론적으로", "요약하자면"으로 시작하는 마무리 문단
- 3개 이상 연속되는 불릿 나열로 설명을 대신하는 것 — 설명은 문단으로, 불릿은 진짜 목록에만
- 모든 절이 같은 길이로 균등한 구조 (중요한 절은 길게, 아닌 절은 두 문장으로 끝내도 됨)
- 장점/단점 표를 기계적으로 붙이는 것 — 선택의 근거만 쓴다

**해야 할 것:**
- 이유를 먼저: "P99를 본다" 앞에 "평균 40ms 뒤에 숨은 3초짜리 요청 1건" 같은 구체적 수치 시나리오
- 트레이드오프 명시: "percentiles-histogram을 켜면 시계열이 버킷 수만큼 는다. 공짜가 아니다"
- 실제 함정 경고: 검색하면 나오는 낡은 정보(Promtail, 구 아티팩트명)를 이름 박아서 정정
- 명령 블록은 실행 결과 예시 또는 성공 판정 기준과 함께
- 단정할 수 없는 것은 조건과 함께: "메모리 12 GiB 미만이면 워커 1개로 줄여라"
- 산출물 명시: 각 모듈 끝에 "이 단계가 남기는 파일"을 적는다

## 다이어그램 제작 규약 — Archify

아키텍처·UML·시퀀스 등 다이어그램 신규 제작은 **archify 스킬**을 쓴다
(`~/.claude/skills/archify` 전역 설치됨, `Skill: archify`로 호출).
손으로 SVG를 그리거나 Mermaid 텍스트를 그대로 문서에 넣지 않는다 —
Mermaid 초안이 있으면 archify에 입력으로 넘겨 변환한다.

유형별 매핑:

| 필요한 그림 | archify 유형 | 강의에서 쓰일 곳 |
|---|---|---|
| 클러스터·관측 스택 구성도 | architecture | M1 전체 아키텍처, M3 스택 구조 |
| 요청 → gateway → order-api 호출 흐름 | sequence | M2 계측 지점, M4 메트릭 발생 경로 |
| 메트릭/로그 수집 파이프라인 | dataflow | M3 (cAdvisor·KSM → Prometheus), M6 (stdout → Alloy → Loki) |
| 알림 발화·해소 상태 전이 | lifecycle | M5 (pending → firing → resolved) |
| 배포·검증 절차 | workflow | M2 빌드팩 빌드 → kind 적재 → 배포 |

작업 절차:

1. 다이어그램 JSON을 만들고 `validate`로 스키마 검증
2. `deliver`로 HTML 산출 후 SVG/PNG 내보내기
3. SVG는 문서 인라인 삽입용, PNG는 슬라이드용 — 기존 `docs/figures/`의
   `NN-figN.{svg,png}` 이중 보관 관례를 따라 저장

```bash
node ~/.claude/skills/archify/bin/archify.mjs validate <유형> <입력.json> --json
node ~/.claude/skills/archify/bin/archify.mjs deliver <유형> <입력.json> <출력.html> --quality showcase
```

기존 `docs/figures/` 도판 20점은 완성본이므로 재제작하지 않고 그대로 재사용한다.
archify 산출물은 밝은 테마를 기본으로 하여 기존 도판(흰 배경, `#585f6b` 선,
ui-monospace 라벨)과 나란히 놓여도 이질감이 없게 한다.

## 작업 시 주의

- `docs/` HTML은 완성본이다. 강의 자료(lectures/)를 만들 때 참조·추출하되,
  docs/ 원본은 요청 없이 수정하지 않는다
- 09 트레이싱은 시리즈에서 의도적으로 뺐다. 강의 자료에서도 "다음 학습 주제"로만 언급
- 06·07·08의 부하 생성 무한 루프는 실습 후 종료 안내를 반드시 포함
- 한글 파일명은 로컬에서는 동작하지만 웹 서버 배포 시 문제될 수 있음 — 신규 파일은
  `lectures/` 아래에서 `m1-관측성-기초.md`처럼 기존 관례를 따르되, 배포 계획이 생기면 영문화 논의

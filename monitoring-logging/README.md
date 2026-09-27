# 모니터링과 로깅 — 발표 자료와 실습

『쿠버네티스 창시자에게 배우는 모범 사례 2판』 3장(모니터링과 로깅)을 바탕으로 한 발표 슬라이드와,
그 내용을 빈 kind 클러스터에서 처음부터 재현하는 실습 가이드.

| 파일 | 내용 |
|---|---|
| `slides.html` | 발표 슬라이드 93장. 브라우저로 열고 방향키로 넘긴다. `N` 발표자 노트, `P` 발표자 화면, `H` 단축키 도움말 |
| `lab-guide.html` | 실습 가이드. 명령 · 옵션 설명 · 실제 실행 결과 · 판정 기준을 단계별로 적었다 |
| `labs/` | 실습에 쓰는 모든 파일 (앱 소스, 매니페스트, Helm 값, 대시보드, k6 스크립트) |
| `src/` | 슬라이드와 가이드의 원본과 빌드 스크립트 |
| `images/` | 발표 화면 캡처. 가이드의 캡처 항목에 적힌 이름(`install.png` 같은 키, 또는 `s16.png` 같은 슬라이드 번호)으로 저장하면 그 슬라이드에 붙는다(`C` 키로 보기) |

## 실습 환경

macOS 기준. Docker 메모리 8GB · CPU 4 이상.

```
brew install --cask docker
brew install kind helm kubernetes-cli k6 jq
```

검증 환경 (2026-09-26): Docker 29.2.1 · kind v0.33.0 (Kubernetes v1.37.0) · kubectl v1.37.0 ·
Helm v4.2.4 · k6 v2.2.0 · kube-prometheus-stack 차트 89.2.2 · Loki 차트 7.3.0 · Alloy 차트 1.12.1

실습은 `lab-guide.html`을 열고 00부터 순서대로 따라 한다. 모든 명령은 이 폴더를 현재 디렉터리로 두고 실행한다.

## labs/

```
labs/
├── kind-cluster.yaml             클러스터 obs (컨트롤 플레인 1 + 워커 2, 컨트롤 플레인 메트릭 주소 열기)
├── apps/
│   ├── journal-api/              Node.js 24 · Express · prom-client (/metrics, JSON 로그)
│   └── order-api/                Spring Boot · JDK 21 (/actuator/prometheus, 톰캣 액세스 로그, /api/chaos/*)
├── k8s/
│   ├── journal.yaml              journal-api 3개 + 레디스
│   ├── order-api.yaml            order-api 2개
│   ├── servicemonitors.yaml      두 앱을 프로메테우스에 연결
│   ├── prometheusrule.yaml       알림 규칙 4개
│   ├── alert-sink.yaml           알림 수신 서버(웹훅). 받은 알림을 로그로 찍는다
│   └── noisy-pod.yaml            로그를 찍고 죽는 파드(kubectl logs의 한계)
├── helm/
│   ├── kps-values.yaml           kube-prometheus-stack
│   ├── loki-values.yaml          Loki 단일 인스턴스
│   └── alloy-values.yaml         Alloy 로그 수집기
├── dashboards/study-red.json     Grafana 대시보드 (ConfigMap으로 넣는다)
└── k6/k6-red.js                  부하: 정상 30/s + 느린 요청 2/s + 에러 3/s
```

## 다시 빌드하기

슬라이드나 가이드를 고친 뒤:

```
python3 src/build.py        # src/slides/*.html + src/figures/*.svg → slides.html
python3 src/build_lab.py    # src/lab-guide.src.html + labs/ 파일 내용 → lab-guide.html
```

`lab-guide.html`은 `labs/` 파일을 본문에 펼쳐 넣으므로, `labs/`를 고쳤을 때도 다시 빌드한다.
`src/slides-old/`는 이전 구성(실패 사례 중심)의 원본이다. 빌드에 쓰이지 않는다.

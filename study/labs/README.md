# 실습 파일 안내

발표자료(`slides/발표자료-쿠버네티스-관측성.html`)를 따라가며 쓰는 실습 파일 모음이다.
발표자료의 명령 블록은 홈 디렉터리의 `~/k8s-observability`를 작업 디렉터리로 전제하므로,
시작 전에 이 폴더를 통째로 복사한다.

```bash
cp -R labs ~/k8s-observability
cd ~/k8s-observability
chmod +x preflight.sh apps/redeploy.sh rebuild.sh
```

## 디렉터리 구조

```
k8s-observability/
├── preflight.sh                    M1 — 도구 버전·도커 자원·cgroup 사전 점검
├── infra/
│   └── kind-cluster.yaml           M1 — 노드 3개, 포트 매핑, 컨트롤 플레인 메트릭 패치
├── apps/
│   ├── order-api/                  M2 — 주문 API (Spring MVC + Actuator, 커스텀 메트릭)
│   ├── gateway/                    M2 — 게이트웨이 (Spring Cloud Gateway WebFlux)
│   ├── redeploy.sh                 M2 — 태그 올려 빌드→적재→교체→롤아웃 한 번에
│   └── chaos/                      M8 — 카오스 실험 매니페스트 + 게임 데이 시트
├── k8s/
│   ├── 00-namespace.yaml           M2 — apps 네임스페이스
│   ├── 10-order-api.yaml           M2 — Deployment + Service (프로브 3종, 라벨)
│   ├── 20-gateway.yaml             M2 — Deployment + Service (NodePort 30080)
│   └── monitoring/
│       ├── 90-servicemonitors.yaml M4 — 앱 2개를 프로메테우스 타깃으로 연결
│       └── 91-prometheusrule.yaml  M5 — 알림 규칙 4개
├── monitoring/
│   ├── kps-values.yaml             M3 — kube-prometheus-stack 헬름 값 파일
│   ├── loki-values.yaml            M6 — Loki 헬름 값 파일
│   ├── alloy-values.yaml           M6 — Alloy 헬름 값 파일
│   └── dashboards/
│       ├── obs-overview.json       M3 — 프로비저닝 확인용 대시보드
│       └── obs-red.json            M5·M6 — RED 패널 + 로그 패널 대시보드
└── rebuild.sh                      M7 — 클러스터 전체를 처음부터 다시 세우는 스크립트
```

헬름에 넘기는 값 파일은 `monitoring/`, `kubectl apply`로 적용하는 매니페스트는
`k8s/`에 있다 — 명령이 다르면 위치도 다르다. `rebuild.sh`가 이 구조를 그대로
참조하므로 파일을 옮기면 스크립트가 깨진다.

## 실습 진행 흐름

발표자료의 모듈 순서 그대로 간다. 각 모듈에서 이 폴더의 파일을 어떻게 쓰는지만 요약한다.
명령 전문과 검증 절차는 발표자료 해당 모듈에 있다.

**M1 — 환경과 클러스터.** `./preflight.sh`로 도구·자원을 점검하고 통과하면
`kind create cluster --name obs --config infra/kind-cluster.yaml`. 이 파일의 kubeadm
패치가 뒤 모듈의 컨트롤 플레인 메트릭 수집을 좌우하므로, 파일을 고치지 말고 그대로 쓴다.

**M2 — 앱 빌드와 배포.** `apps/order-api`, `apps/gateway`에서
`./gradlew bootBuildImage`로 이미지를 굽고 `kind load`로 적재한 뒤
`kubectl apply -f k8s/00-namespace.yaml -f k8s/10-order-api.yaml -f k8s/20-gateway.yaml`.
이후 코드를 고칠 때마다 `apps/redeploy.sh order-api 0.0.2`처럼 태그를 올려 재배포한다.
매니페스트의 서비스 라벨과 포트 이름은 M4의 연결 고리이므로 바꾸면 안 된다.

**M3 — 관측 스택.** `monitoring/kps-values.yaml`로 kube-prometheus-stack 헬름 설치,
`monitoring/dashboards/obs-overview.json`으로 대시보드 프로비저닝을 확인한다.
설치보다 타깃 검증이 본체다 — 발표자료의 검증 절차를 끝까지 따라간다.

**M4 — 앱 메트릭 연동.** `k8s/monitoring/90-servicemonitors.yaml`을 적용하되,
발표자료 순서대로 일부러 한 번 실패시킨 뒤 고친다. RED 질의는 파일이 아니라
프로메테우스 화면에 직접 입력한다.

**M5 — 대시보드와 알림.** `monitoring/dashboards/obs-red.json`을 ConfigMap으로 등록하고
`k8s/monitoring/91-prometheusrule.yaml` 적용. 알림 발화 실습은 부하 루프를 켠 상태에서 한다.

**M6 — 로깅.** `monitoring/loki-values.yaml`, `monitoring/alloy-values.yaml`로
로그 스택 설치. 메모리 여유 2 GiB를 먼저 확인한다.

**M7 — 운영.** 실습을 부수고 다시 세워보는 단계 — `./rebuild.sh`.
운영 전환 체크리스트는 발표자료 M7에 있다.

**M8 — 카오스 실험.** 실험마다 `apps/chaos/gameday-sheet.md`를 복사해
가설을 먼저 쓰고, `apps/chaos/`의 매니페스트를 적용한다.

## 주의

- 버전 숫자는 실습 당일 `helm search repo`로 재확인한다. 값 파일의 차트 버전이
  저장소 최신과 크게 어긋나면 발표자료 M3의 안내대로 맞춘다
- 부하 생성 무한 루프와 포트포워드는 실습이 끝나면 반드시 끈다
- 전부 정리하려면 `kind delete cluster --name obs`

# 쿠버네티스 관측성 실습

강의안·실습서·실습 코드·외부 예제 저장소를 **한 축으로 합친 것**이다.
이론과 실습이 같은 문서 안에 있어 한 곳만 고치면 된다.

시작 지점은 [`index.html`](index.html)이다.

```
study/
├── index.html          로드맵 · 장 목록 · 버전
├── ch00 ~ ch10.html    11장. 장마다 이론 → 설치 → 따라하기 → 실패 → 검증 → 명령어
├── labs/               실습 코드 (문서의 코드 블록이 정본, 여기는 실행 가능한 형태)
│   ├── apps/           order-api · gateway · chaos 실험 정의
│   ├── infra/          kind 클러스터 설정
│   ├── k8s/            매니페스트
│   └── monitoring/     values · 대시보드 JSON
├── scripts/            fetch-samples.sh
└── ppt/                별도 저장소가 장표를 만들 때 쓰는 키트
```

## 합쳐진 것

| 원래 있던 곳 | 무엇 | 지금 |
|---|---|---|
| `lectures/*.md` 8편 | 이론 | 각 장 01절 |
| `docs/*.html` 11편 | 따라하기 | 각 장 02~11절 |
| `labs/` | 실습 코드 | `study/labs/` |
| `villainscode/kubernetes` | 외부 예제 앱 2종 | `scripts/fetch-samples.sh` 로 커밋 고정해 받아 온다 |

`docs/k8s-observability-study/` 는 `docs/kubernetes-monitoring/docs/` 의
바이트 단위 복제본이었다. 둘 다 여기로 합치고 원본은 지웠다.

10장(테스팅과 카오스)은 강의안만 있고 실습서가 없어 **새로 썼다.**

## 실습 코드

문서의 코드 블록이 정본이고 `labs/` 는 그 실행 가능한 형태다. 어긋나면 문서를 기준으로 맞춘다.

`order-api` 의 커스텀 메트릭 이름 `orders.created` · `orders.rejected` ·
`orders.processing` · `orders.stored` 는 **바꾸지 않는다.**
06장 PromQL 과 07장 대시보드 JSON 이 이 이름에 의존한다.

외부 예제 앱은 복사해 두지 않는다.

```bash
bash scripts/fetch-samples.sh
```

## 버전

2026-08-19 검증 기준 **Kubernetes 1.36 · kind v0.32.0 · 차트 88.x** 에 고정돼 있다.
문서의 실행 결과가 이 조합에서 실제로 실행해 얻은 것이라 그대로 유지한다.

같은 저장소의 [`course/`](../course/index.html) 38편 과정은 2026-09-03 기준
**1.37.0 · kind v0.33.0 · 차트 89.2.2** 다. 두 과정을 같은 클러스터에서 섞어 돌리지 않는다.
이 시리즈를 1.37 라인으로 올리려면 11장의 명령과 출력을 다시 검증해야 한다.

## PPT

장표는 여기서 만들지 않는다. `ppt/` 의 세 가지를 별도 저장소가 받아 제작한다.

- `ppt/outline.md` — 56장표 아웃라인 (제목 · 화면 · 말할 것 · 넘어가며)
- `ppt/figures/` — 도판 PNG 5종과 원본 명세 JSON
- `ppt/GUIDE.md` — 판형 · 팔레트 · 코드 처리 · 금지 사항

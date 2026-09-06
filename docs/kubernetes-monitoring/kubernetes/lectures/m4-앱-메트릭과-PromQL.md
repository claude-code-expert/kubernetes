# M4 · 앱 메트릭 연동과 PromQL

이론: 책 3.5(어떤 메트릭을 모니터링하나)
실습: docs/06(ServiceMonitor 연동, 의도적 실패, RED 질의)
검증일 2026-08-19 기준. 소요 70~90분 — 시리즈에서 가장 긴 모듈이다.

## 1. 왜 이걸 하나

M3의 타깃 지도는 노드와 클러스터 컴포넌트로 꽉 찼는데 정작 우리 앱이 없다.
`orders_created_total`을 질의하면 빈 결과가 나온다. M2에서 앱은
`/actuator/prometheus`를 열어뒀고, M3에서 프로메테우스는 긁을 준비를 마쳤다.
서로 존재를 모를 뿐이다.

연결 고리는 ServiceMonitor 하나다. 그런데 이 선언이 효력을 가지려면 **라벨 세 겹**이
모두 맞아야 하고, 하나라도 어긋나면 아무 오류 없이 조용히 무시된다. M3에서
라벨 없는 대시보드 ConfigMap이 조용히 무시되는 것을 봤다 — 같은 성질의 문제를
이번에는 더 아픈 위치에서 만난다. 대부분의 사람이 첫 번째 겹에서 막히므로,
이 모듈은 일부러 한 번 실패시킨 뒤 고치는 순서로 간다.

연결이 끝나면 PromQL로 RED 지표를 직접 쓴다. 여기서 만드는 질의 6개가 M5
대시보드의 패널이 된다.

## 2. 이론 — 무엇을 모니터링하나 (책 3.5)

"전부 다"는 답이 아니다. 책의 계층 — 노드, 클러스터 컴포넌트, 클러스터 애드온,
애플리케이션 — 중 앞의 셋은 M3에서 타깃으로 확보했다. 남은 것이 애플리케이션
계층이고, 책이 이 계층에서 타깃팅하라는 항목은 컨테이너 메모리 사용률·포화도,
CPU 사용률, 네트워크 사용률·에러율, 그리고 **애플리케이션 프레임워크에 특정한
메트릭**이다.

앞의 셋은 cAdvisor가 이미 준다(M3의 kubelet 타깃). 마지막 하나 — 초당 요청 수,
5xx 비율, P99 응답 시간, 분당 주문 수 — 는 앱이 직접 내보내야 하고, M2에서
Micrometer로 심어둔 것이 바로 이것이다. M1에서 배운 RED 방법론이 이 계층의
프레임이다: Rate(처리율), Errors(에러율), Duration(지연). 애플리케이션 관측은
이 셋으로 시작해서 이 셋으로 끝난다.

한 가지 더 — 기술 지표만으로는 부족하다. "에러율 0%, P95 정상"인데 매출이 떨어지는
상황이 있다. 주문 수가 평소의 30%로 줄었는데 응답 시간은 오히려 좋아졌다면,
사용자가 들어오지 못하고 있다는 뜻일 수 있다. 그래서 RED 옆에 비즈니스 지표
(분당 주문 수, 거부율)를 나란히 둔다. 대시보드 맨 위에 비즈니스 지표를 두는 팀이
늘어나는 이유다.

## 3. 라벨 세 겹

ServiceMonitor는 "이 서비스를 긁어라"라는 선언이다. 효력의 조건 세 가지:

1. **ServiceMonitor의 `release` 라벨** — 오퍼레이터가 프로메테우스 CR의 셀렉터로
   ServiceMonitor를 고른다. M3 릴리스 이름이 `kps`였으므로 `release: kps`
2. **`spec.selector`와 Service의 라벨** — ServiceMonitor가 Service를 찾는 고리.
   M2 배포 때 `app.kubernetes.io/name: order-api`를 붙여둔 것
3. **`endpoints.port`와 Service의 포트 이름** — 숫자가 아니라 **이름**이다.
   M2에서 포트에 `http`라는 이름을 준 이유

②와 ③은 M2에서 이미 준비해 뒀다. 이번에 새로 만드는 것은 ①과 ServiceMonitor뿐이다.

## 4. 일부러 실패시켜 보기

`release` 라벨 없이 만들어 본다. 5분이면 되고, 이 경험이 앞으로 몇 시간을 아껴준다.

```bash
mkdir -p ~/k8s-observability/k8s/monitoring
cd ~/k8s-observability/k8s/monitoring

cat <<'EOF' > 90-servicemonitor-broken.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: order-api-broken
  namespace: apps
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: order-api
  namespaceSelector:
    matchNames: [apps]
  endpoints:
    - port: http
      path: /actuator/prometheus
EOF

kubectl apply -f 90-servicemonitor-broken.yaml
kubectl -n apps get servicemonitor
```

리소스는 정상적으로 만들어진다. 타깃에 나타나는지 확인한다:

```bash
sleep 40
curl -s --get http://localhost:30900/api/v1/query \
  --data-urlencode 'query=up{namespace="apps"}' \
  | jq '.data.result | length'
```

```
0
```

0이다. 오류 메시지도, 경고 로그도 없다. 프로메테우스 CR의 셀렉터를 직접 보면
이유가 드러난다:

```bash
kubectl -n monitoring get prometheus -o yaml \
  | grep -A4 'serviceMonitorSelector:'
```

```
  serviceMonitorSelector:
    matchLabels:
      release: kps
```

차트는 `serviceMonitorSelectorNilUsesHelmValues: true`를 기본으로 둔다.
"이 헬름 릴리스가 관리하는 것만 본다"는 뜻으로, 한 클러스터에 프로메테우스를
여러 개 띄우는 상황(팀별 분리 등)에서 서로의 타깃을 침범하지 않게 하는 장치다.
값 파일에 `false`를 넣어 무력화할 수도 있지만 실습에서는 넣지 않는다 —
라벨을 붙이는 쪽이 원리를 드러내고, 운영 클러스터에서도 그쪽이 표준이다.

```bash
kubectl delete -f 90-servicemonitor-broken.yaml
```

## 5. ServiceMonitor 작성

`k8s/monitoring/90-servicemonitors.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: order-api
  namespace: apps
  labels:
    # ① M3 헬름 릴리스 이름과 일치해야 오퍼레이터가 고른다
    release: kps
spec:
  # ② 이 라벨을 가진 Service를 찾는다 (M2에서 붙여둔 것)
  selector:
    matchLabels:
      app.kubernetes.io/name: order-api
  namespaceSelector:
    matchNames:
      - apps
  endpoints:
    # ③ Service의 포트 '이름'이다. 숫자가 아니다.
    - port: http
      path: /actuator/prometheus
      # 전역 설정과 같은 값. 명시해두면 나중에 이 서비스만 조정하기 쉽다.
      interval: 30s
      scrapeTimeout: 10s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: gateway
  namespace: apps
  labels:
    release: kps
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: gateway
  namespaceSelector:
    matchNames:
      - apps
  endpoints:
    - port: http
      path: /actuator/prometheus
      interval: 30s
      scrapeTimeout: 10s
```

```bash
kubectl apply -f 90-servicemonitors.yaml
kubectl -n apps get servicemonitor
```

배치 작업처럼 Service를 붙이지 않는 워크로드는 PodMonitor를 쓴다. 구조는 같고
②번 고리가 Service 대신 파드 라벨로 바뀐다. Service가 있다면 ServiceMonitor가
낫다 — 엔드포인트 정보를 쿠버네티스가 관리해주기 때문이다.

## 6. 연결 검증

세 단계로 확인한다. 순서가 곧 디버깅 순서다.

**1. 타깃이 생겼는가:**

```bash
sleep 40
curl -s --get http://localhost:30900/api/v1/query \
  --data-urlencode 'query=up{namespace="apps"}' \
  | jq -r '.data.result[] | "\(.metric.job)\t\(.metric.pod)\t\(.value[1])"'
```

```
gateway     gateway-7d9c4b8f6-qk2xp     1
order-api   order-api-6b8f7d5c9-h4nm2   1
order-api   order-api-6b8f7d5c9-t8wcv   1
```

파드 3개가 각각 하나의 타깃이다. 서비스가 아니라 **파드 단위**로 긁는다.
레플리카를 늘리면 타깃도 자동으로 늘어난다.

**2. 앱 메트릭이 실제로 들어왔는가:**

```bash
curl -s --get http://localhost:30900/api/v1/query \
  --data-urlencode 'query=orders_created_total' \
  | jq -r '.data.result[] | "\(.metric.pod)\t\(.value[1])"'
```

비어 있으면 요청을 몇 번 보내고 40초 기다린다.

**3. 오퍼레이터가 만든 설정을 직접 열어보기** — 가장 확실한 디버깅 방법이다.
프로메테우스가 실제로 읽는 설정은 시크릿에 gzip으로 들어 있다:

```bash
kubectl -n monitoring get secret prometheus-kps-kube-prometheus-prometheus \
  -o jsonpath='{.data.prometheus\.yaml\.gz}' \
  | base64 -d | gunzip | grep -A12 'job_name.*order-api' | head -20
```

`job_name`이 보이면 ①번 고리는 통과다. 여기에 없으면 라벨 문제, 있는데도 타깃이
0개면 ②·③번 문제다. 이 명령 하나로 원인을 절반으로 좁힌다.

## 7. 프로메테우스가 붙여준 라벨

앱은 `orders_created_total{channel="api"}` 하나만 내보냈는데, 저장된 시계열에는
라벨이 훨씬 많다:

```json
{
  "__name__": "orders_created_total",
  "channel": "api",
  "container": "order-api",
  "endpoint": "http",
  "instance": "10.244.1.7:8080",
  "job": "order-api",
  "namespace": "apps",
  "pod": "order-api-6b8f7d5c9-h4nm2",
  "service": "order-api"
}
```

`channel`만 앱이 붙인 것(M2의 `Counter.builder`)이고, `job`은 Service 이름,
`namespace`·`pod`·`service`·`container`는 쿠버네티스 서비스 디스커버리가 자동으로
부여한다. M2에서 앱에 `application=order-api` 같은 공통 태그를 넣지 않은 이유가
여기 있다 — 넣었다면 `job`·`service`와 의미가 겹치는 라벨이 세 개가 되고, 질의마다
무엇으로 묶을지 고민하다 팀원마다 다른 라벨을 쓰기 시작한다. 쿠버네티스에서는
수집 계층이 붙여주는 라벨을 표준으로 삼는 것이 깔끔하다.

## 8. PromQL 최소 문법

`localhost:30900/graph`에 직접 입력하며 읽는다. 필요한 개념은 네 개뿐이다.

**1. 카운터는 그대로 보면 쓸모가 없다.** 계속 오르기만 하는 누적값이기 때문이다.
거의 항상 `rate()`를 씌운다. 대괄호 안의 시간은 "이만큼을 돌아보며 평균 낸다"는
뜻이고, 스크레이프 간격의 4배 이상을 권장한다. 우리는 30초 간격이므로 최소 2분.

**2. `sum by` — 필요한 축만 남긴다:**

```promql
# 파드별로 흩어진 값을 서비스 단위로 합친다
sum by (service) (rate(orders_created_total[2m]))

# by 대신 without을 쓰면 "이 라벨만 빼고 나머지로 묶어라"
sum without (pod, instance) (rate(orders_created_total[2m]))
```

**3. 히스토그램에서 분위수 뽑기.** 왜 평균이 아니라 분위수인가 — 요청 100건 중
99건이 10ms, 1건이 3초면 평균은 40ms다. 대시보드는 초록색이고, 그 1건을 겪은
사용자는 이탈한다. P99를 보면 3초가 그대로 드러난다.

```promql
# le(less or equal) 라벨을 반드시 남겨야 한다. 빠지면 계산이 안 된다.
histogram_quantile(
  0.95,
  sum by (le, service) (rate(http_server_requests_seconds_bucket{namespace="apps"}[5m]))
)
```

Prometheus 3.8부터 네이티브 히스토그램이 정식 기능이 됐고 버킷 시계열 폭증 문제를
근본적으로 줄여준다. 다만 그라파나 패널과 기존 대시보드가 아직 고전 버킷 기준인
경우가 많아 이 실습은 고전 버킷(`_bucket`)으로 진행한다. 전환 판단은 M7에서.

**4. 비율 계산에서 조심할 것** — 트래픽이 없으면 분모가 0이 되어 결과가 비어버린다.
대시보드 'No data'의 흔한 원인이다.

## 9. RED 지표 완성

아래 질의들이 M5 대시보드의 패널이 된다.

**R — 서비스별 초당 요청 수:**

```promql
sum by (service) (
  rate(http_server_requests_seconds_count{namespace="apps"}[2m])
)
```

**E — 서비스별 5xx 비율(%):**

```promql
100 * (
  sum by (service) (
    rate(http_server_requests_seconds_count{namespace="apps", status=~"5.."}[5m])
  )
  /
  sum by (service) (
    rate(http_server_requests_seconds_count{namespace="apps"}[5m])
  )
)
```

**D — 서비스별 P95 응답 시간(초):**

```promql
histogram_quantile(
  0.95,
  sum by (le, service) (
    rate(http_server_requests_seconds_bucket{namespace="apps"}[5m])
  )
)
```

**D 심화 — 엔드포인트별 P99, 느린 순서대로:**

```promql
topk(5,
  histogram_quantile(
    0.99,
    sum by (le, uri) (
      rate(http_server_requests_seconds_bucket{namespace="apps", service="order-api"}[5m])
    )
  )
)
```

`uri` 라벨이 `/api/orders/{id}`처럼 템플릿으로 찍혀 있는 것을 확인한다.
M2에서 `@PathVariable`로 매핑한 덕분이다 — ID가 그대로 찍혔다면 시계열이
주문 수만큼 늘어났을 것이다.

**비즈니스 지표 — 분당 주문 수와 거부율:**

```promql
sum(rate(orders_created_total[5m])) * 60

100 * (
  sum(rate(orders_rejected_total[5m]))
  /
  (sum(rate(orders_created_total[5m])) + sum(rate(orders_rejected_total[5m])))
)
```

## 10. 지연 전파 관찰

서비스를 둘로 나눈 이유를 확인할 차례다. 백엔드를 느리게 만들고 게이트웨이의
지연이 어떻게 따라 움직이는지 본다.

```bash
# 터미널 1 — 평상시 트래픽을 계속 흘린다
while true; do
  curl -s -o /dev/null -X POST http://localhost:30080/api/orders \
    -H 'Content-Type: application/json' \
    -d '{"item":"latte","quantity":2}'
  sleep 0.3
done
```

```bash
# 터미널 2 — 3분 동안 느린 요청을 섞는다
end=$((SECONDS+180))
while [ "$SECONDS" -lt "$end" ]; do
  curl -s -o /dev/null "http://localhost:30080/api/chaos/slow?ms=900"
  sleep 1
done
echo "지연 주입 종료"
```

두 질의를 그래프에 함께 띄워 비교한다:

```promql
# 게이트웨이가 본 P95 (클라이언트 관점)
histogram_quantile(0.95,
  sum by (le) (rate(http_server_requests_seconds_bucket{service="gateway"}[2m]))
)

# 백엔드가 본 P95 (서버 관점)
histogram_quantile(0.95,
  sum by (le) (rate(http_server_requests_seconds_bucket{service="order-api"}[2m]))
)
```

패턴 해석: 두 값이 거의 같이 오르면 백엔드가 원인이고 게이트웨이는 기다렸을 뿐이다.
게이트웨이만 오르고 백엔드가 평온하면 게이트웨이 자체 병목(커넥션 풀, CPU, 라우팅
필터)을 의심한다. 백엔드만 오르고 게이트웨이가 그대로면 느린 경로가 게이트웨이를
거치지 않았거나 타임아웃으로 잘리고 있다. 게이트웨이의 라우트 단위 지표
`spring_cloud_gateway_requests_seconds_bucket`(라벨 `routeId`)으로 한 번 더
확인할 수 있다.

**실습이 끝나면 반드시 터미널 1의 부하 루프를 Ctrl+C로 끈다.** 켜둔 채 잊으면
노트북 팬이 계속 돌고, 프로메테우스 저장 공간(M3에서 8Gi)이 예상보다 빨리 찬다.

## 11. 지금부터 조심할 것 — 카디널리티

앱 메트릭이 붙는 순간 시계열 개수가 급증한다. `http_server_requests_seconds_bucket`
하나가 (엔드포인트 수) × (상태 코드 수) × (버킷 수) × (파드 수)만큼의 시계열을
만든다. 실습 규모에서는 문제없지만, 운영에서 `uri` 태그에 ID가 섞이는 순간
프로메테우스가 메모리 부족으로 죽는다. M7의 주제다. 지금 수치를 적어두면 나중에
비교하기 좋다:

```promql
prometheus_tsdb_head_series
topk(10, count by (__name__) ({__name__=~".+"}))
```

자주 겪는 문제는 docs/06 문서 09절 표에 정리돼 있다. 요지만: 타깃 목록에 앱이
아예 없으면 ①번 고리(release 라벨), 타깃 그룹은 있는데 대상이 0개면 ②번 고리
(Service 라벨), 404면 path와 exposure 설정, `_bucket`만 없으면 M2의
percentiles-histogram 설정, `histogram_quantile`이 NaN이면 `sum by`에서 `le` 누락.

## 12. 검증

- `release` 라벨 없이 만들면 타깃이 안 생긴다는 것을 직접 확인했다
- `up{namespace="apps"}` 결과가 파드 3개 모두 1이다
- 시크릿에서 생성된 스크레이프 설정을 열어 `job_name`을 확인했다
- 메트릭에 `job`·`namespace`·`pod`·`service` 라벨이 붙어 있다
- RED 질의 세 개가 모두 값을 반환한다
- `uri` 라벨이 `/api/orders/{id}` 형태로 템플릿화되어 있다
- 지연 주입 실습에서 게이트웨이와 백엔드의 P95 곡선을 함께 봤다
- 부하 생성 루프를 종료했다

## 13. 다음 단계

이 모듈이 남기는 것: `90-servicemonitors.yaml`, 그리고 질의 6개(RED 3 + P99 심화 +
비즈니스 2). 질의들을 팀 저장소 메모에 정리해 둔다 — M5에서 그대로 패널이 된다.

M5에서는 이 질의들을 M3의 프로비저닝 방식으로 대시보드에 옮기고, 변수
(namespace·service)를 넣어 하나의 대시보드로 여러 서비스를 본다. 그리고
PrometheusRule로 알림 규칙을 선언한 뒤 Alertmanager에서 라우팅한다. 기술보다
어려운 질문 — "알림을 몇 개 만들 것인가" — 도 함께 다룬다.

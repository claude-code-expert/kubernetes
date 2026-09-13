# 캡스톤 장애 시나리오 3종 — 정답지 (강사용)

**수강생에게 배포하지 않는다.** 제한 시간 90분, 도구는 대시보드·로그·이벤트·kubectl 만.

주입: `bash scripts/incident.sh inject <번호>` · 정리: `bash scripts/incident.sh clear all`

---

## 장애 1 — "대시보드가 비었어요"

### 주입
```
kubectl -n journal patch servicemonitor journal-api --type=merge \
  -p '{"metadata":{"labels":{"release":"kps-typo"}}}'
```

### 관찰되는 증상 (실측)
```
프로메테우스 journal-api 타깃 수: 0
인그레스 /api/entries: 200          <- 서비스는 멀쩡하다
```
- 그라파나 패널이 `No data`
- 파드는 전부 `Running`, 이벤트에 아무것도 없다
- `AppTargetDown` 알림도 **울리지 않는다** (타깃이 down 이 아니라 아예 없다)

### 정답
`ServiceMonitor` 의 `release` 라벨이 프로메테우스의 `serviceMonitorSelector` 와 맞지 않는다.
M20 의 3단 라벨 사슬 중 **첫 번째 고리**가 끊어진 것이다.

### 찾아가는 길
1. 프로메테우스 `Status → Targets` 에서 `journal-api` 가 **목록에 없다**는 것부터 확인
   (down 과 없음은 다르다 — 없으면 셀렉터 문제다)
2. `kubectl -n monitoring get prometheus -o jsonpath='{.items[0].spec.serviceMonitorSelector}'`
   → `{"matchLabels":{"release":"kps"}}`
3. `kubectl -n journal get servicemonitor journal-api --show-labels`
   → `release=kps-typo`
4. 라벨을 고친다

### 흔한 오답
- 앱을 재시작한다 (아무 관계 없다)
- `/metrics` 엔드포인트를 확인한다 (정상이다 — 긁어 가는 쪽 문제다)

---

## 장애 2 — "아까는 됐는데 지금은 안 돼요"

### 주입
```
kubectl -n journal delete netpol allow-dns
```

### 관찰되는 증상 (실측)
```
기존 파드에서: nslookup redis-0.redis  -> ;; connection timed out
인그레스 /api/entries: 200            <- 지금 도는 요청은 멀쩡하다
새로 만든 파드: 정상으로 뜬다 (이 앱은 기동 시 DNS 를 쓰지 않는 경로가 있다)
```
**증상이 즉시 나타나지 않는 것이 이 장애의 핵심**이다.
저널 API 파드를 재시작하면 그때 레디스에 못 붙어 `/readyz` 가 503 이 된다.

### 정답
`journal` 네임스페이스는 `default-deny`(양방향)이고, DNS 를 여는 정책이 사라졌다.
M25 에서 재현한 그 사고다.

### 찾아가는 길
1. 파드 **안에서** 이름 해석을 해 본다 — `kubectl exec ... -- nslookup`
2. `timed out` 이면 DNS 서버에 닿지 못하는 것이다 (`NXDOMAIN` 은 다른 이야기다)
3. `kubectl -n journal get netpol` → `allow-dns` 가 없다
4. `kubectl apply -f k8s/netpol/10-allow.yaml`

### 흔한 오답
- CoreDNS 를 재시작한다 (CoreDNS 는 멀쩡하다)
- `/etc/resolv.conf` 를 본다 (설정은 정상이다 — 나가는 길이 막힌 것이다)

---

## 장애 3 — "느린데 어디를 봐도 한가해요"

### 주입
```
kubectl -n journal patch deploy journal-api --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"50m"}]'
```

### 관찰되는 증상 (실측, 150 rps 부하 중)
```
lat_list: avg=3.42s  p(90)=22.7s  p(95)=31.13s  max=45.08s
http_req_failed: 80.29%
kubectl top pods: 50m / 48m       <- limit 에 딱 붙어 있다
파드 상태: 전부 Running, 재시작 0
이벤트: 없음
```

### 정답
`cpu limit: 50m` 때문에 CFS 스로틀링이 걸렸다. M37 의 실험 그대로다.

### 찾아가는 길
1. `kubectl top` 이 **limit 과 같은 값**을 보이면 그 자체가 신호다
2. 스로틀링 질의:
```
sum by (pod) (rate(container_cpu_cfs_throttled_periods_total{namespace="journal",container="api"}[2m]))
/ sum by (pod) (rate(container_cpu_cfs_periods_total{namespace="journal",container="api"}[2m]))
```
   → 88~96%
3. `kubectl -n journal get deploy journal-api -o jsonpath='{...resources}'` 에서 `limits.cpu` 확인
4. 제거하거나 넉넉히 올린다

### 흔한 오답
- 파드를 늘린다 (HPA 가 이미 늘렸고 전부 같은 limit 이라 나아지지 않는다)
- 레디스를 의심한다 (레디스는 멀쩡하다)
- 노드를 본다 (노드는 한가하다)

---

## 채점 기준

| 항목 | 배점 |
|---|---|
| 세 장애의 **증상**을 정확히 기술 | 30 |
| 각 장애의 **원인**을 지목 | 30 |
| 원인을 **어떤 관찰로** 좁혔는지 설명 | 30 |
| 재발 방지책 제안 (알림·정책·점검 항목) | 10 |

원인만 맞히고 경로를 설명하지 못하면 **절반만 준다.**
운영에서 필요한 것은 답이 아니라 **답에 이르는 절차**다.

## 재발 방지책 (모범 답안)

1. **장애 1** — `ServiceMonitor` 라벨을 M26 의 어드미션 정책으로 강제한다.
   또는 "타깃 수가 0인 job" 을 알림으로 만든다 (`absent()` 를 쓴다)
2. **장애 2** — `allow-dns` 를 GitOps 로 관리하면 selfHeal 이 5초 만에 되돌린다 (M31).
   그리고 네트워크 정책 변경을 CI 에서 검사한다 (M32 의 region-check 형태)
3. **장애 3** — 스로틀링 패널과 알림을 M21 대시보드에 추가한다.
   `cpu limit` 을 넣는 변경은 어드미션 정책으로 리뷰를 강제한다

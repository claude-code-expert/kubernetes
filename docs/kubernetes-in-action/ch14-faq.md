# Chapter 14 — FAQ: 운영자가 자주 묻는 30개 질문

> 14장 슬라이드의 Q&A 3개로는 부족한 영역. 발표 후 후속 질문, 운영팀의 디버깅 케이스, PR 리뷰에서 마주치는 패턴을 정리.

---

## 카테고리

- [A. requests/limits 기본기](#a-requestslimits-기본기) — 6개
- [B. QoS / LimitRange / ResourceQuota](#b-qos--limitrange--resourcequota) — 4개
- [C. HPA / VPA / KEDA](#c-hpa--vpa--keda) — 8개
- [D. CPU/메모리 throttling과 OOM](#d-cpu메모리-throttling과-oom) — 5개
- [E. 클라우드별 운영 차이 (EKS/GKE/AKS)](#e-클라우드별-운영-차이) — 4개
- [F. 비용 최적화](#f-비용-최적화) — 3개

---

## A. requests/limits 기본기

### Q1. requests를 크게 잡으면 더 빠른가?

**아니다.** requests는 스케줄러가 노드 선택 시 'requests 합 ≤ Allocatable'을 검사할 때만 쓰는 입력값이다. 실제 사용은 limits까지 가능. requests를 크게 잡으면 노드 빈자리만 미리 잡고 다른 Pod이 못 들어와 클러스터 자원이 낭비된다.

운영 권장값:
- `requests` = 평균 사용량 (P50)
- `limits` = P99 × 1.5

### Q2. CPU limits 빼면 안 되나?

**상황에 따라 다르다.** Tim Hockin(K8s SIG-Node lead)이 2022년 권장: "core 집약적이지 않은 워크로드는 CPU limits 없이 가는 게 throttle 회피"

- **빼도 되는 경우**: 짧은 burst가 잦은 워크로드(JVM, Node.js, Python 시작), 사이드카(istio-proxy)
- **반드시 잡아야 하는 경우**: 멀티테넌시(다른 팀 워크로드와 같은 노드), 비용 통제가 중요한 경우

memory limits는 항상 잡는다(메모리 누수 보호).

### Q3. millicore(m)는 정확히 무엇인가?

`1 core = 1000m`. CPU 시간의 1/1000을 의미. `200m`은 1 vCPU의 20% 사용 시간 = period당 20ms (period 100ms 기준).

**중요**: millicore는 절대 시간 단위. 노드 vCPU 개수와 무관. 즉 `200m`은 어느 노드에서 실행되든 같은 양의 CPU 시간을 의미.

### Q4. 메모리 단위 Mi와 M의 차이는?

| 단위 | 값 |
|---|---|
| 1 Ki | 1024 bytes |
| 1 Mi | 1024 × 1024 = 1,048,576 bytes |
| 1 K | 1000 bytes |
| 1 M | 1,000,000 bytes |

K8s 운영 표준은 Mi/Gi(이진 단위). Pod 메모리 측정도 이진 단위 기준이라 일치.

### Q5. requests만 설정하고 limits 생략하면 어떻게 되는가?

QoS는 **Burstable**. limits는 노드 Allocatable까지 사용 가능 (사실상 unlimited).

함정: 노드 메모리 압박 시 cgroup oom_score_adj 계산이 `min(max(2, 1000 - (1000 × memory.requests / total)), 999)`. **requests가 작으면 점수가 커서 더 먼저 죽는다**.

권장: requests를 평균에 맞춰 잡되 너무 작게 잡지 말 것. 또는 limits도 같이 잡아 Guaranteed로.

### Q6. Pod 안에 컨테이너가 여러 개면 requests/limits는 어떻게 평가되나?

**컨테이너별 정의 + Pod 합으로 스케줄링**:

```yaml
spec:
  containers:
  - name: app      # requests cpu 200m, limits cpu 400m
  - name: sidecar  # requests cpu 100m, limits cpu 200m
# Pod 합: requests cpu 300m, limits cpu 600m
# 스케줄러는 Pod 합(300m)이 노드 Allocatable에 들어가는지 검사
```

QoS는 **모든 컨테이너 기준**:
- 모두 requests=limits → Guaranteed
- 일부만 설정 또는 requests<limits → Burstable
- 모두 미설정 → BestEffort

1.32 alpha의 Pod-level resources를 쓰면 컨테이너 단위 생략하고 Pod 단위로만 정의 가능.

---

## B. QoS / LimitRange / ResourceQuota

### Q7. QoS Class를 직접 지정할 수 있나?

**아니다.** spec에 `qosClass` 필드는 없다. requests/limits로부터 K8s가 자동 결정해 `.status.qosClass`에 채운다.

운영 의의: 의도와 다른 QoS로 떨어진 Pod을 status로 검증.

```bash
kubectl get pods -A -o json | jq -r '.items[] |
  select(.status.qosClass != "Guaranteed") |
  "\(.metadata.namespace)/\(.metadata.name): \(.status.qosClass)"'
```

### Q8. LimitRange와 Helm chart values 중 어느 쪽이 우선인가?

**chart values가 우선.** LimitRange는 admission 단계 마지막에 default를 채우므로, manifest에 명시값이 있으면 그게 이긴다.

LimitRange의 역할:
- `default`: manifest에 없을 때만 자동 부여
- `defaultRequest`: 위와 동일
- `max`/`min`: manifest의 명시값이라도 위반 시 거부

`maxLimitRequestRatio`는 `limits/requests` 비율 상한. burst 정도를 제한.

### Q9. ResourceQuota를 켰는데 기존 Pod이 한도를 넘고 있다면?

**기존 Pod은 그대로 둔다.** ResourceQuota는 admission 단계 강제라 신규 Pod 생성 시에만 평가. 즉 켜는 시점의 사용량은 그대로 유지되고, 그 이후의 신규 Pod만 한도 안에서만 가능.

단계적 도입 방법:
1. 현재 사용량보다 약간 큰 값으로 ResourceQuota 적용 (기존 Pod 영향 없음)
2. 천천히 한도 낮춤 (사용량 줄여가며)
3. 목표 한도까지 도달

### Q10. ResourceQuota와 LimitRange 중 어느 것을 먼저 적용해야 하나?

**LimitRange 먼저, 그 다음 ResourceQuota.**

이유: ResourceQuota는 namespace 합계를 본다. LimitRange가 없으면 BestEffort Pod (requests 없음)이 만들어지는데, ResourceQuota가 `requests.cpu` 한도를 두면 BestEffort Pod은 0으로 계산되어 한도 회피가 가능. 보안 관점에서 LimitRange로 default를 강제한 후 Quota를 적용해야 일관성 있음.

운영 표준: LimitRange + ResourceQuota를 같은 Helm chart로 묶어 namespace 생성 시 한 번에 적용.

---

## C. HPA / VPA / KEDA

### Q11. HPA + VPA를 같이 쓸 수 있나?

**CPU 메트릭은 충돌, 메모리 메트릭은 가능.**

CPU 충돌 이유: HPA가 CPU 사용률을 보고 replica를 늘림 → Pod당 CPU 사용량 감소 → VPA가 requests를 줄임 → 같은 사용률에서 다시 replica 늘림 → 무한 루프 또는 oscillation.

메모리는 가능: 메모리는 사용량이 replica 수에 무관(각 Pod이 독립적으로 메모리 사용). HPA(CPU 메트릭) + VPA(메모리만 조정)는 안전.

가장 안전한 패턴: HPA 단독 + VPA `Off` 모드(추천만) + 사람이 PR로 반영.

### Q12. HPA가 `<unknown>`에 머물러 있다

체크리스트:
1. **metrics-server 동작**: `kubectl top node`로 검증. 안 되면 metrics-server 설치 또는 `--kubelet-insecure-tls` 추가.
2. **Pod의 requests 설정**: HPA `Utilization` 타입은 requests 기준. requests 없으면 계산 불가.
3. **1분 대기**: 신규 HPA는 metrics-server scrape 주기(15초) × 4회 평균 후 평가.
4. **Events 확인**: `kubectl describe hpa` → `FailedGetResourceMetric`이 계속 나오면 metrics-server 도달 실패.

### Q13. HPA의 tolerance가 뭔가?

기본 10%. 즉 `abs(currentMetric - desiredMetric) / desiredMetric < 0.1`이면 변화 없음. 50% 목표인데 49%여도 scale down 안 됨.

이게 운영에서 "HPA가 동작 안 하는 것처럼 보이는" 가장 흔한 이유. 좁히려면 kube-controller-manager의 `--horizontal-pod-autoscaler-tolerance=0.05` 옵션.

대부분의 클라우드 매니지드 K8s(EKS, GKE, AKS)는 control plane 옵션 변경 불가. 그래서 tolerance 10%는 사실상 고정.

### Q14. behavior 정책의 권장값은?

**scale up은 빠르게, scale down은 천천히** — flapping 방지 표준 패턴:

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 0
    policies:
    - { type: Percent, value: 100, periodSeconds: 15 }   # 15초 안에 최대 2배
  scaleDown:
    stabilizationWindowSeconds: 300                       # 5분 안정화
    policies:
    - { type: Percent, value: 50, periodSeconds: 60 }     # 1분에 최대 절반
```

scaleDown stabilizationWindow가 작으면 트래픽 출렁임에 replica가 요동친다. 300초가 운영 표준.

### Q15. VPA의 updateMode 권장값은?

**프로덕션은 `Off` (recommendation 모드).**

| 값 | 동작 | 권장 환경 |
|---|---|---|
| `Off` | 추천만, 적용 안 함 | 모든 환경 (사람이 PR로 반영) |
| `Initial` | Pod 생성 시에만 적용 | 스테이징 (재배포가 잦은 환경) |
| `Recreate` | Pod 재생성하며 적용 | 비-프로덕션 |
| `Auto` | 현재는 Recreate와 같음. 1.27 in-place GA 후 in-place로 진화 예정 | GA 후 재검토 |

Auto는 Pod 재생성 = 다운타임. 프로덕션에서는 위험.

### Q16. KEDA가 HPA를 대체하나?

**아니다. KEDA는 HPA를 확장한다.**

KEDA는 ScaledObject마다 HPA를 자동 생성:
```bash
kubectl get hpa
keda-hpa-my-scaledobject   <unknown>/1 (avg)   1   5   3   1m
```

KEDA의 역할:
- 외부 시스템 메트릭(SQS depth, Kafka lag)을 `external.metrics.k8s.io`로 노출
- HPA가 그 메트릭으로 평가
- `minReplicaCount: 0`일 때 0↔1 전환은 KEDA가 직접 (HPA로는 불가능)

즉 KEDA = "HPA의 메트릭 변환기 + 0→N 처리기".

### Q17. KEDA의 polling interval은 어떻게 결정?

기본 `pollingInterval: 30` (초). KEDA가 30초마다 외부 시스템에 메트릭 조회.

함정: SQS에 메시지가 도착하고 Pod이 실제로 시작하기까지 **최대 polling interval + Pod 시작 시간**. 빠른 응답이 필요하면:
- `pollingInterval: 5`처럼 짧게 (단 외부 시스템 부하)
- 또는 KEDA HTTP Add-on(KEDA-HTTP)으로 push 모델 채택

### Q18. KEDA Scaler 중 자주 쓰이는 것은?

| Scaler | 용도 |
|---|---|
| AWS SQS Queue | SQS 큐 길이 기반 (메시지 처리 워커) |
| AWS Kinesis Stream | Kinesis shard별 lag |
| Apache Kafka | Kafka consumer group lag |
| Prometheus | PromQL 기반 (가장 강력 — 사실상 모든 메트릭 가능) |
| Cron | 시간 기반 (배치 잡, 야간 작업) |
| HTTP Add-on | HTTP request rate (Knative 대안) |
| Redis | Redis list/stream 길이 |

운영에서 가장 많이 쓰는 건 **Prometheus Scaler** — 다른 모든 메트릭을 PromQL로 변환해서 일원화 가능.

---

## D. CPU/메모리 throttling과 OOM

### Q19. CPU throttling을 어떻게 측정하나?

```bash
kubectl exec <POD> -- cat /sys/fs/cgroup/cpu.stat
# nr_periods 1234        (총 period)
# nr_throttled 56        (throttle 발생 period)
# throttled_usec 5678000 (throttle 시간 누적, μs)
```

`nr_throttled / nr_periods` = throttle 비율.
- 1% 미만: 정상
- 1~5%: 경고 (limits 늘리거나 워크로드 검토)
- 5% 이상: 심각 (P99 latency 영향)

Datadog, Prometheus의 `container_cpu_cfs_throttled_seconds_total` 메트릭으로도 추적 가능.

### Q20. OOMKill이 발생했는데 메모리 사용량이 limits 미만이라면?

**가능한 원인 3가지**:

1. **노드 전체 메모리 부족** (kubelet eviction): Pod 자체는 limits 이하지만 노드가 메모리 부족이라 kubelet이 종료. `kubectl get events` → `Reason: Evicted`.

2. **cgroup 누계 vs RSS 차이**: limits는 cgroup의 메모리 누계(RSS + cache + swap). `kubectl top pod`은 RSS만 표시. cache가 limits에 포함되어 있어 보이는 사용량보다 실제가 많을 수 있음.

3. **fork bomb 또는 child 프로세스**: 컨테이너 안에서 fork된 자식 프로세스의 메모리도 cgroup에 합산. `ps aux`로 확인.

대응:
```bash
kubectl describe pod <POD> | grep -A 5 "Last State"
# Reason: OOMKilled
# Exit Code: 137

# 노드에서 cgroup 확인 (cgroup v2)
cat /sys/fs/cgroup/<pod>/<container>/memory.events
# oom_kill 1
```

### Q21. CPU Manager static을 활성화하면 무엇이 바뀌나?

**Guaranteed Pod이고 `requests.cpu`가 정수**일 때만 CPU 핀닝.

효과:
- CFS quota 우회 → throttle 사라짐
- L1/L2 캐시 hit rate 향상
- NUMA 메모리 지역성 향상

함정:
- 한 번 활성화하면 정책 변경 시 노드 drain 필요
- 노드 Allocatable CPU가 정수 단위로 줄어듦 → bin packing 효율 저하

운영 케이스: 고성능 데이터베이스(Cassandra), 머신러닝 추론, 실시간 처리(Kafka Stream).

### Q22. 메모리 limits를 낮추는 방법이 있나?

**낮추는 건 안전하지 않다.**

K8s 1.32+ in-place resize에서도 메모리 limits 낮추기는 거부. 이유: 이미 사용 중인 메모리를 회수할 수 없음. 낮춘 후 OOMKill 발생 가능.

대응:
- `Recreate` strategy로 Pod 재생성 (=다운타임 허용)
- 또는 메모리 누수가 의심되면 pprof로 root cause 찾고 코드 수정

메모리 limits 늘리기는 in-place resize로 가능 (재시작 없음).

### Q23. 노드 자원 압박을 사전에 감지하는 방법?

**cgroup v2 PSI (Pressure Stall Info)**:

```bash
cat /sys/fs/cgroup/memory.pressure
# some avg10=12.34 avg60=10.21 avg300=8.55
# full avg10=2.15  avg60=1.80  avg300=1.50
```

- `some`: 일부 작업이 자원 부족으로 대기 중
- `full`: 모든 작업이 자원 부족으로 대기 중

운영 임계값:
- `memory.pressure full avg10 > 1%` → 경고
- `memory.pressure full avg10 > 5%` → 즉시 워크로드 재배치

Karpenter 같은 노드 오토스케일러는 PSI를 보고 새 노드를 미리 띄움.

---

## E. 클라우드별 운영 차이

### Q24. EKS에서 metrics-server 설치는?

EKS는 metrics-server가 기본 설치 안 됨. Helm 또는 manifest로 설치:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

EKS는 정식 CA로 kubelet TLS verification 가능 — `--kubelet-insecure-tls` 추가 불필요.

만약 IRSA(IAM Roles for Service Accounts)가 필요하면 metrics-server SA에 role 부여:
```bash
eksctl create iamserviceaccount --cluster <CLUSTER> --namespace kube-system \
  --name metrics-server --role-only ...
```

### Q25. GKE에서 VPA 설치는?

GKE는 VPA가 매니지드 — addon으로 활성화:

```bash
gcloud container clusters update <CLUSTER> --enable-vertical-pod-autoscaling
```

VPA admission webhook 인증서 자동 발급. 별도 설치 불필요.

VPA Auto 모드도 GKE에서는 안전 — Pod 재생성 시 GKE가 PDB(PodDisruptionBudget)를 존중.

### Q26. AKS의 KEDA 설치는?

AKS는 KEDA가 addon으로 제공 (1.24+):

```bash
az aks update --resource-group <RG> --name <CLUSTER> --enable-keda
```

매니지드 KEDA는 자동 업그레이드 + Microsoft 지원. 단 일부 Scaler(예: 외부 SaaS)는 직접 설치한 KEDA에서만 가능.

EKS/GKE는 KEDA 직접 설치:
```bash
kubectl apply --server-side -f https://github.com/kedacore/keda/releases/download/v2.16.0/keda-2.16.0.yaml
```

### Q27. 클라우드 vs 베어메탈에서 cgroup 버전 차이?

| 환경 | cgroup 버전 |
|---|---|
| Amazon Linux 2 | v1 |
| Amazon Linux 2023 | v2 |
| GKE Container-Optimized OS (COS) 1.25+ | v2 |
| AKS Ubuntu 1.25+ | v2 |
| Bottlerocket | v2 (1.0 default) |
| 베어메탈 Ubuntu 22.04+ | v2 default |

cgroup v2 권장 — MemoryQoS, PSI, OOM 단위 변경 같은 개선이 v2에서만 가능.

---

## F. 비용 최적화

### Q28. 자원을 효율적으로 사용하는 방법?

**Bin packing 향상 4가지**:

1. **requests를 정확하게** — P50 사용량으로 잡으면 노드당 더 많은 Pod 가능
2. **VPA recommendation** — 권장값을 보고 PR로 반영 (8일 P95 기반)
3. **Karpenter** — Pod의 requests에 맞춰 노드 자체를 동적으로 추가/제거
4. **PodDisruptionBudget + de-scheduler** — 비효율 노드의 Pod 재배치

### Q29. KEDA `minReplicaCount: 0`을 쓰면 비용을 얼마나 절약?

**예측**: 야간/주말 트래픽이 0인 워크로드는 70~90% 노드 시간 절약.

함정:
- Cold start 1~5초 (이미지 캐시 안 된 노드는 더 김)
- 첫 요청은 KEDA polling interval(기본 30초) 만큼 지연 가능
- 사용자 직접 트래픽에는 부적절. SQS/Kafka consumer, 배치 잡, 야간 ETL에 적합.

### Q30. spot instance + K8s 자원 관리 조합?

**기본 패턴**:

1. **PriorityClass**로 워크로드 분류:
   - `system-critical`: spot 금지
   - `production`: spot OK이지만 PDB로 보호
   - `batch`: spot 권장
2. **nodeSelector** 또는 **taints/tolerations**로 spot 노드 선택
3. **PodDisruptionBudget**으로 spot termination 시 동시 종료 제한
4. **HPA + VPA recommendation**으로 자원 적정화

비용 절감: spot 가격 60~90% 할인 + bin packing으로 노드 시간 추가 30%. 합쳐 70~95% 비용 절감 가능.

위험: spot termination notice는 2분 전 통지. graceful shutdown이 그 안에 끝나야 함. liveness probe + preStop hook + terminationGracePeriodSeconds 조정 필수.

---

## 더 깊이

이 FAQ에 답이 없는 질문은 다음 자료 참조:

- **`ch14-deep-dive.md`** — cgroup v2, CPU/Topology Manager, DRA, MemoryQoS, HPA internals
- **`ch14-resources-detailed-notes.md`** — 14장 전체 이론 + 디버깅 런북 8개
- **`ch14-presentation.md`** — 슬라이드 1:1 발표 스크립트 + 운영 사고 사례 3건

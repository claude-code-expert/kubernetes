# Chapter 14 — Deep Dive: 슬라이드에 안 들어간 고급 주제

> 14장 슬라이드와 발표 스크립트는 입문~중급용. 본 문서는 시니어/SRE/플랫폼 엔지니어가 운영에서 만나는 깊은 주제를 정리.

---

## 목차

1. [cgroup v1 vs v2 — K8s가 자원을 강제하는 메커니즘](#1-cgroup-v1-vs-v2)
2. [CPU throttling과 CFS quota period의 진실](#2-cpu-throttling)
3. [CPU Manager — static / none / restricted 정책](#3-cpu-manager)
4. [Topology Manager — NUMA 핀닝과 GPU 워크로드](#4-topology-manager)
5. [DRA (Dynamic Resource Allocation, 1.32 beta)](#5-dra)
6. [MemoryQoS — cgroup v2의 memory.high 활용](#6-memoryqos)
7. [HPA 내부 계산 알고리즘과 메트릭 lag](#7-hpa-internals)

---

## 1. cgroup v1 vs v2

### 1.1 왜 알아야 하는가

`requests`/`limits`가 어떻게 강제되는지의 답은 **cgroup**. 운영에서 OOM 로그가 이상하거나, CPU throttle 양상이 직관과 다를 때 cgroup 버전을 확인해야 원인을 안다.

| 항목 | cgroup v1 | cgroup v2 |
|---|---|---|
| 파일시스템 마운트 | `/sys/fs/cgroup/<controller>/...` (controller별 분리) | `/sys/fs/cgroup/...` (단일 hierarchy) |
| CPU limits 파일 | `cpu.cfs_quota_us`, `cpu.cfs_period_us` | `cpu.max` |
| 메모리 limits 파일 | `memory.limit_in_bytes` | `memory.max` |
| 메모리 reclaim hint | 없음 | `memory.high` (soft limit, throttle 발동) |
| OOMKill 동작 | 컨테이너 단위 | Pod 단위 또는 컨테이너 단위 (선택) |
| Pressure Stall Info (PSI) | 없음 | `cpu.pressure`, `memory.pressure`, `io.pressure` |
| K8s 지원 | 1.0~ | 1.25 GA, 1.27부터 default |

### 1.2 cgroup 버전 확인

```bash
# 컨테이너 안에서
cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null && echo "v2" || echo "v1"

# 노드에서
stat -fc %T /sys/fs/cgroup/
# cgroup2fs → v2
# tmpfs     → v1 (또는 hybrid)
```

### 1.3 cgroup v2의 운영 가치

**Pressure Stall Info (PSI)** — 자원 압박을 정량화:

```bash
cat /sys/fs/cgroup/memory.pressure
# some avg10=12.34 avg60=10.21 avg300=8.55 total=12345678
# full avg10=2.15  avg60=1.80  avg300=1.50 total=2345678
```

- `some` = 일부 작업이 자원 부족으로 대기 중
- `full` = 모든 작업이 자원 부족으로 대기 중

운영에서는 `avg10`(최근 10초 평균)을 모니터링. `memory.pressure full > 1%`이면 경고, `> 5%`이면 즉시 노드 증설 또는 워크로드 재배치.

**memory.high** — soft limit으로 OOM 대신 throttle:

```bash
echo "1G" > /sys/fs/cgroup/<pod>/<container>/memory.high
```

K8s의 MemoryQoS feature gate가 켜져 있으면 자동으로 `memory.high`를 `requests.memory`로 설정. 메모리 압박 시 OOMKill 직전에 reclaim이 먼저 시도됨.

### 1.4 cgroup v2 강제 활성화

EKS/GKE는 노드 OS 이미지에 따라 결정:
- Amazon Linux 2 → cgroup v1
- Amazon Linux 2023 → cgroup v2
- GKE Container-Optimized OS (COS) — 1.25+ → v2 default

minikube에서 cgroup v2 강제:

```bash
minikube start --container-runtime=containerd --feature-gates=MemoryQoS=true
```

---

## 2. CPU throttling

### 2.1 CFS quota의 동작

Linux Completely Fair Scheduler(CFS)의 quota는 **period 단위로 evaluate**.

기본값:
- `cpu.cfs_period_us = 100000` (100ms)
- `cpu.cfs_quota_us = limits.cpu × cpu.cfs_period_us`

`limits.cpu: 200m`이면 `cfs_quota_us = 20000` (20ms). 즉 **100ms 중 최대 20ms만 CPU 사용 가능**. 21ms째부터 throttle, 다음 period(100ms 후)까지 대기.

### 2.2 burst 워크로드의 함정

JVM JIT 컴파일, GC, Python 시작, Node.js 초기화 같은 **짧은 burst**는 100% CPU를 짧은 시간 사용:

```
워크로드: 시작 시 30ms 동안 1 vCPU 100% 사용

limits.cpu = 500m (50ms / period) → quota 50ms, 30ms 사용 → 통과
limits.cpu = 200m (20ms / period) → quota 20ms, 30ms 필요 → 첫 20ms 후 80ms throttle
                                                        → 실제 30ms 작업이 100ms로 늘어남
```

결과: **P99 latency 5배 증가**. 평균은 정상으로 보여 디버깅 어려움.

### 2.3 throttle 측정

```bash
kubectl exec <POD> -- cat /sys/fs/cgroup/cpu.stat
# nr_periods 1234        (총 period 수)
# nr_throttled 56        (throttle 발생 period 수)
# throttled_usec 5678000 (throttle 시간 누적, μs)
```

**nr_throttled / nr_periods > 1%** 이면 throttle 영향이 있음. 5% 이상이면 심각.

### 2.4 대응 방법

**방법 1: limits 늘리기**
- 가장 단순. burst 만큼 + 안전 마진. 보통 P99 사용량의 1.5~2배.
- 단점: 노드 자원 비효율 (실제로는 거의 안 쓰는데 limit으로 잡힌 자원)

**방법 2: CFS quota period 줄이기 (1.30+ alpha)**
- `--cpu-cfs-quota-period=10ms`로 period를 짧게
- burst에 더 자주 quota 보충 → throttle 감소
- 단점: 스케줄러 오버헤드 증가

**방법 3: CPU Manager static 정책 (Guaranteed Pod 한정)**
- CPU 핀닝 → CFS quota 자체 우회
- 다음 섹션 참조

**방법 4: limits 제거**
- Burstable QoS로 떨어지지만 throttle 사라짐
- 단점: BestEffort까지는 가지 않지만 노드 자원 부족 시 종료 우선순위 ↑
- Tim Hockin(K8s SIG-Node lead)이 2022년 권장: "core 집약적이지 않은 워크로드는 limits 없이 가는 것이 throttle 회피"

### 2.5 K8s 1.32 권장 운영 패턴

```yaml
# burst 워크로드(JVM, Node.js)
spec:
  containers:
  - resources:
      requests: { cpu: "200m", memory: "256Mi" }
      # limits.cpu 의도적으로 제거 (Burstable로 throttle 회피)
      limits:   { memory: "512Mi" }
```

memory limits는 유지(메모리 누수 방지), CPU limits는 burst 워크로드에서 제거하는 게 1.32+ 권장.

---

## 3. CPU Manager

### 3.1 3가지 정책

| 정책 | 동작 |
|---|---|
| `none` | 기본값. CFS quota만 사용. 모든 Pod이 모든 CPU에서 실행 가능 |
| `static` | Guaranteed Pod(CPU integer requests)만 CPU 핀닝. CFS quota 우회 |
| `restricted` | 1.31+. NUMA-aware, Topology Manager와 연동 |

### 3.2 static 정책 활성화

kubelet 설정:

```yaml
# /var/lib/kubelet/config.yaml
cpuManagerPolicy: static
reservedSystemCPUs: "0,1"   # 시스템용으로 예약
kubeReserved:
  cpu: "500m"
systemReserved:
  cpu: "500m"
```

Guaranteed Pod이고 `requests.cpu`가 정수일 때만 핀닝 적용:

```yaml
# 핀닝 받음
spec:
  containers:
  - resources:
      requests: { cpu: "2", memory: "2Gi" }
      limits:   { cpu: "2", memory: "2Gi" }   # = requests → Guaranteed

# 핀닝 못 받음 (소수)
spec:
  containers:
  - resources:
      requests: { cpu: "1500m", memory: "2Gi" }
      limits:   { cpu: "1500m", memory: "2Gi" }
```

### 3.3 static 정책의 가치

- CFS quota 우회 → throttle 사라짐
- L1/L2 캐시 hit rate 증가 → 동일 CPU에 계속 실행됨
- NUMA 아키텍처에서 메모리 지역성 향상

운영 케이스:
- 고성능 데이터베이스 (Cassandra, Aerospike)
- 머신러닝 추론 서버
- 실시간 처리 (Kafka Stream, Flink)

### 3.4 함정

- 한 번 static으로 활성화하면 정책 변경 시 노드 drain 필요 (kubelet 재시작 + Pod 재배포)
- 노드의 Allocatable CPU가 정수 단위로 줄어듦 → bin packing 효율 감소
- Burstable Pod은 핀닝 안 됨 → 같은 노드에 static + burstable이 섞이면 burstable이 핀닝된 CPU 영역을 침범 가능 (kubelet이 cpuset 격리)

---

## 4. Topology Manager

### 4.1 왜 필요한가

NUMA 아키텍처:
- 노드의 CPU와 메모리가 NUMA node로 분리
- node 0의 CPU가 node 1의 메모리에 접근하면 latency 2~3배

GPU/네트워크 카드도 PCIe slot에 따라 특정 NUMA node에 연결됨. ML 워크로드는 GPU + 메모리 + CPU가 같은 NUMA node에 있어야 성능이 나옴.

### 4.2 정책

| 정책 | 동작 |
|---|---|
| `none` | NUMA 무시 |
| `best-effort` | 가능하면 같은 NUMA, 안 되면 분산 |
| `restricted` | 같은 NUMA에 못 잡으면 admission denied |
| `single-numa-node` | 가장 엄격 — 단일 NUMA 강제 |

### 4.3 활성화

```yaml
# /var/lib/kubelet/config.yaml
topologyManagerPolicy: single-numa-node
cpuManagerPolicy: static
```

CPU Manager static + Topology Manager 조합으로 사용. 보통 `best-effort`가 운영 표준.

### 4.4 ML 워크로드 예시

```yaml
spec:
  containers:
  - name: training
    resources:
      requests:
        cpu: "8"
        memory: "32Gi"
        nvidia.com/gpu: "1"
      limits:
        cpu: "8"
        memory: "32Gi"
        nvidia.com/gpu: "1"
```

Topology Manager가 GPU의 NUMA node를 보고 같은 node의 CPU 8개 + 메모리 32Gi를 핀닝. 다른 NUMA node의 자원이 부족해도 이 Pod은 그 자리를 안 받음.

---

## 5. DRA (Dynamic Resource Allocation)

### 5.1 기존 모델의 한계

K8s의 GPU 표현:
```yaml
resources:
  limits:
    nvidia.com/gpu: 1   # 정수, opaque, 공유 불가
```

문제:
- GPU를 부분 공유 못 함 (예: 2개 Pod이 1 GPU의 다른 메모리 영역)
- GPU 모델별 차별 표현 못 함 (A100 40GB vs A100 80GB)
- 우선순위 기반 할당 못 함

### 5.2 DRA 모델 (1.32 beta)

```yaml
# ResourceClass — 디바이스 종류 정의
apiVersion: resource.k8s.io/v1beta1
kind: DeviceClass
metadata: { name: nvidia-gpu }
spec:
  selectors:
  - cel:
      expression: device.driver == "gpu.nvidia.com"
---
# ResourceClaim — 특정 디바이스 요청
apiVersion: resource.k8s.io/v1beta1
kind: ResourceClaim
metadata: { name: gpu-claim }
spec:
  spec:
    devices:
      requests:
      - name: gpu
        deviceClassName: nvidia-gpu
        selectors:
        - cel:
            expression: device.attributes["gpu.nvidia.com"].memory >= "40Gi"
---
# Pod — claim 참조
apiVersion: v1
kind: Pod
spec:
  resourceClaims:
  - { name: gpu, source: { resourceClaimName: gpu-claim } }
  containers:
  - resources:
      claims: [{ name: gpu }]
```

### 5.3 운영 가치

- **부분 공유**: 한 GPU를 여러 Pod이 메모리 분할로 공유
- **속성 기반 선택**: CEL 표현식으로 메모리 크기, compute capability 등 선택
- **vendor-neutral**: NVIDIA/AMD/Intel을 같은 모델로 표현
- **partitioning**: MIG (Multi-Instance GPU) 자동 관리

### 5.4 채택 시점

- 1.32 beta → 1.33 GA 예상 (2025 말~2026 초)
- 운영 채택은 GA 후 NVIDIA Driver/Operator 지원 확인 후
- 현재 nvidia.com/gpu 모델은 1.34까지 호환 유지 예정

---

## 6. MemoryQoS

### 6.1 기존 동작 (cgroup v1)

`limits.memory: 512Mi` → 512Mi 도달 즉시 OOMKill. 회수(reclaim) 없음.

문제: 메모리 사용량이 일시적으로 spike하면 즉시 죽음. 평균은 100Mi인데 GC 직전 spike에 800Mi 찍는 워크로드는 limits를 어떻게 잡든 죽거나 자원을 낭비.

### 6.2 MemoryQoS (cgroup v2 + 1.27+ feature gate)

`memory.high` 메커니즘:
- `requests.memory ≤ usage ≤ limits.memory` 사이에서 reclaim 시도
- reclaim 실패 시 throttle (메모리 할당 지연)
- 그래도 안 되면 OOMKill

자동 매핑:
```
memory.high = requests.memory  (또는 requests × throttle factor)
memory.max  = limits.memory
```

### 6.3 활성화

K8s 1.32 alpha (1.27 alpha → 1.31 beta → 1.32 beta).

```yaml
# kubelet config
featureGates:
  MemoryQoS: true
```

cgroup v2 노드에서만 동작. EKS Amazon Linux 2023, GKE COS 1.27+에서 가능.

### 6.4 운영 효과

- Burstable Pod의 안정성 향상 — spike 시 즉시 OOM 대신 reclaim
- P99 메모리 사용률이 limits 가까이 가는 워크로드(예: JVM, Redis)에 효과적
- BestEffort Pod은 영향 없음 (request 0이라 throttle 발동 조건 없음)

---

## 7. HPA Internals

### 7.1 평가 알고리즘

```
desiredReplicas = ceil[currentReplicas × (currentMetricValue / desiredMetricValue)]
```

예: 현재 4 replica, CPU 사용률 80%, 목표 50%:
```
desired = ceil[4 × (80 / 50)] = ceil[6.4] = 7
```

### 7.2 메트릭 수집 주기

| 단계 | 주기 |
|---|---|
| metrics-server scrape kubelet | 15초 |
| HPA controller 평가 | 15초 |
| Pod의 메트릭이 HPA에 반영 | **최대 30~60초 지연** |

신규 Pod이 시작해서 HPA가 그 Pod의 메트릭을 보기까지 ~1분. 즉 부하가 급증해도 HPA의 첫 반응까지 1분 이상 걸림.

### 7.3 tolerance (실제로는 동작 안 함처럼 보이는 영역)

```
abs(currentMetric - desiredMetric) / desiredMetric < tolerance(default 0.1)
```

기본 tolerance 10%. 즉 CPU 45%~55% 사이는 변화 없음. 50% 목표인데 49%에 머물러도 scale down 안 됨.

이게 운영에서 "HPA가 동작하지 않아 보이는" 가장 흔한 원인. tolerance를 좁히려면:

```yaml
# kube-controller-manager 옵션
--horizontal-pod-autoscaler-tolerance=0.05
```

### 7.4 stabilizationWindow vs cooldown 시간

| 메커니즘 | 의미 |
|---|---|
| scaleUp.stabilizationWindowSeconds | 이 시간 동안의 권장 replica 중 **min** 채택 (보수적 — 너무 빨리 늘리지 않음) |
| scaleDown.stabilizationWindowSeconds | 이 시간 동안의 권장 replica 중 **max** 채택 (보수적 — 너무 빨리 줄이지 않음) |

scaleUp 0초 + scaleDown 300초가 운영 표준. 빠르게 늘리고 천천히 줄임.

### 7.5 메트릭 종류별 평가 차이

**Resource (CPU/메모리)** — `Utilization` 타입:
```
currentMetric = (모든 Pod의 actual CPU 사용량 합) / (모든 Pod의 requests.cpu 합) × 100%
```

**Resource — `AverageValue` 타입**:
```
currentMetric = (모든 Pod의 actual CPU 사용량 합) / replica 수
# Pod당 평균 사용량 (millicore 단위)
```

**Pods 메트릭**:
```
currentMetric = (모든 Pod의 메트릭 합) / replica 수
```

**Object 메트릭** (Ingress, Service):
```
currentMetric = 객체의 메트릭 값 / replica 수
```

**External 메트릭** (KEDA에서 자주 사용):
```
currentMetric = 외부 시스템에서 가져온 raw 값 (per replica로 나누지 않음)
```

이 차이를 모르면 SQS depth가 1000인데 replica 1로 안 늘어나는 사고 발생.

### 7.6 다중 메트릭 평가

여러 메트릭이 있으면 **각각 desiredReplicas 계산 후 max** 채택:

```yaml
metrics:
- type: Resource (cpu)        → desired 5
- type: Resource (memory)     → desired 3
- type: Pods (rps)            → desired 7
# HPA 결정: max(5, 3, 7) = 7
```

scale up은 보수적(가장 큰 메트릭이 이김), scale down은 모든 메트릭이 충분히 낮아야 발동 — 안전한 방향.

### 7.7 HPA + KEDA 통합 시 동작

KEDA는 ScaledObject마다 HPA를 자동 생성:

```bash
kubectl get hpa
NAME                              REFERENCE         TARGETS              MINPODS   MAXPODS
keda-hpa-my-scaledobject          Deployment/app    <unknown>/1 (avg)    1         5
```

KEDA가 external metric을 `external.metrics.k8s.io`로 노출 → HPA가 그 메트릭으로 평가. 즉 KEDA = HPA 입력 변환기 + 0→N 처리기.

ScaledObject `minReplicaCount: 0`이면:
- 큐가 비어있으면 KEDA가 `--replicas=0`으로 직접 scale down (HPA 우회)
- 큐에 메시지 도착 시 KEDA가 `--replicas=1`로 직접 scale up
- 1 이상이 되면 HPA가 정상 동작

이 흐름을 모르면 "KEDA가 1까지만 늘리고 안 늘어남" 같은 디버깅이 됨 (HPA의 max를 늘려야 함).

---

## 더 깊이 — 추가 학습 자료

### 공식 문서
- cgroup v2: https://kubernetes.io/docs/concepts/architecture/cgroups/
- CPU Manager: https://kubernetes.io/docs/tasks/administer-cluster/cpu-management-policies/
- Topology Manager: https://kubernetes.io/docs/tasks/administer-cluster/topology-manager/
- DRA: https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/

### 권장 읽기
- KEP-2570 (cgroup v2): https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/2570-memory-qos
- Tim Hockin's "For the love of god, stop using CPU limits": https://home.robusta.dev/blog/stop-using-cpu-limits
- Datadog "Kubernetes resource limits investigation": (내부 사례)

### 관련 도구
- `cri-tools` — `crictl` 명령으로 노드의 cgroup 상태 직접 조회
- `oomd` (Facebook) — userspace OOM killer, cgroup v2 PSI 활용
- `verbruger` — cgroup v2 기반 메모리 quota 동적 조정 도구
- Karpenter (AWS) — autoscaler가 노드 자체를 동적으로 추가/제거 (HPA의 위 계층)

// 저널 서비스 API — 책 1장 예제의 최소 구현.
// REDIS_URL 이 있으면 레디스에, 없으면 메모리에 엔트리를 저장한다.
// M14에서 레디스와 함께 쿠버네티스에 배포하고, M20에서 메트릭을 붙인다.
import express, { Request, Response, NextFunction } from 'express';
import { createClient, RedisClientType } from 'redis';
import client from 'prom-client';

// ── 계측 (M20) ────────────────────────────────────────────────────────────
// 프로세스·런타임 기본 지표(메모리·GC·이벤트 루프 지연 등)를 등록한다.
client.collectDefaultMetrics();

// 이름과 라벨을 order-api(Micrometer) 와 맞춘다.
// 두 앱의 지표 이름이 다르면 대시보드와 알림 규칙을 앱마다 따로 써야 한다.
// buckets 는 order-api 의 application.yml 이 정한 SLO 경계와 같게 둔다.
const httpDuration = new client.Histogram({
  name: 'http_server_requests_seconds',
  help: 'HTTP 요청 처리 시간(초)',
  labelNames: ['method', 'uri', 'status', 'outcome'] as const,
  // 버킷 경계는 이 앱의 실제 지연 분포에 맞춰야 한다.
  // 처음에는 order-api 의 SLO 경계(50ms~1s)를 그대로 베꼈는데, 이 앱은 1ms 대에서
  // 응답하므로 모든 요청이 첫 버킷에 몰렸다. 그러면 P50 이 [0, 0.05] 구간의
  // 선형 보간값(25ms)으로 나온다 — 평균 1ms 와 25배 차이 나는 허수다.
  // 아래로 낮춰 잡으면 분위수가 실제 값을 따라간다. 대신 시계열이 버킷 수만큼 는다.
  buckets: [0.0005, 0.001, 0.0025, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1],
});

import { normalizeUri, outcomeOf } from './labels.js';

const app = express();
app.use(express.json());
// 모든 요청의 소요 시간을 잰다. 라우트보다 먼저 등록해야 전부 잡힌다.
app.use((req: Request, res: Response, next: NextFunction) => {
  const end = httpDuration.startTimer();
  const startedAt = Date.now();
  res.on('finish', () => {
    const uri = normalizeUri(req.path);
    end({
      method: req.method,
      uri,
      status: String(res.statusCode),
      outcome: outcomeOf(res.statusCode),
    });
    // 요청 로그 (M22). 메트릭은 "몇 건인가"를, 로그는 "무엇이었나"를 답한다.
    // 프로브 요청까지 남기면 로그의 대부분이 헬스 체크가 된다 — 걸러 낸다.
    if (uri === '/healthz' || uri === '/readyz' || uri === '/metrics') return;
    log(res.statusCode >= 500 ? 'error' : 'info', 'request', {
      method: req.method,
      // path 를 그대로 남긴다. 라벨이 아니라 로그 본문이므로 카디널리티 문제가 없다 (M22 8절).
      path: req.originalUrl,
      status: res.statusCode,
      durationMs: Date.now() - startedAt,
      pod: INSTANCE,
    });
  });
  next();
});


const PORT = Number(process.env.PORT ?? 8080);
const REDIS_URL = process.env.REDIS_URL;
const VERSION = process.env.APP_VERSION ?? 'v1';
// 쿠버네티스는 HOSTNAME 을 파드 이름으로 설정한다. 어느 파드가 응답했는지 보려고 함께 돌려준다.
const INSTANCE = process.env.HOSTNAME ?? 'local';
// M30 — 나쁜 버전을 만들기 위한 손잡이. 0 이면 아무 일도 하지 않는다.
// 카오스 주입을 앱에 두는 것은 실습을 위한 선택이다. 운영 코드에 두면 언젠가 켜진다.
const FAULT_RATE = Number(process.env.FAULT_RATE ?? 0);

const memory = new Map<string, string>();
let redis: RedisClientType | undefined;

function log(level: string, msg: string, extra: Record<string, unknown> = {}): void {
  // 로그는 파일이 아니라 표준 출력으로 (M22 로그 수집의 전제).
  console.log(JSON.stringify({ level, msg, ...extra }));
}

async function connectRedis(): Promise<void> {
  if (!REDIS_URL) {
    log('info', 'no REDIS_URL, using in-memory store');
    return;
  }
  const client = createClient({
    url: REDIS_URL,
    socket: { reconnectStrategy: (retries) => Math.min(retries * 200, 3000) },
  });
  client.on('error', (e) => log('error', 'redis error', { detail: String(e) }));
  await client.connect();
  redis = client as RedisClientType;
  log('info', 'redis connected', { url: REDIS_URL });
}

// 프로메테우스가 긁어 갈 엔드포인트 (M20).
// order-api 는 액추에이터가 /actuator/prometheus 로 열지만, 여기서는 직접 연다.
// 경로가 다르므로 ServiceMonitor 도 앱마다 따로 써야 한다.
app.get('/metrics', async (_req: Request, res: Response) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

// 프로세스가 살아 있는지. 실패하면 재시작이 답이다 (M15 라이브니스).
app.get('/healthz', (_req: Request, res: Response) => {
  res.json({ status: 'ok', version: VERSION, pod: INSTANCE });
});

// 트래픽을 받을 준비가 됐는지. 저장소에 못 붙었으면 503 (M15 레디니스).
app.get('/readyz', (_req: Request, res: Response) => {
  if (REDIS_URL && !redis?.isOpen) {
    res.status(503).json({ status: 'not ready', reason: 'redis not connected' });
    return;
  }
  res.json({ status: 'ready' });
});

app.get('/api/entries', async (_req: Request, res: Response) => {
  if (FAULT_RATE > 0 && Math.random() < FAULT_RATE) {
    log('error', 'injected fault', { rate: FAULT_RATE });
    res.status(500).json({ error: 'injected fault' });
    return;
  }
  if (redis?.isOpen) {
    const keys = await redis.keys('entry:*');
    const values = keys.length ? await redis.mGet(keys) : [];
    res.json({ entries: values.filter(Boolean) });
    return;
  }
  res.json({ entries: [...memory.values()] });
});

app.post('/api/entries', async (req: Request, res: Response) => {
  const id = String(Date.now());
  const body = JSON.stringify(req.body ?? {});
  if (redis?.isOpen) {
    await redis.set(`entry:${id}`, body);
  } else {
    memory.set(id, body);
  }
  res.status(201).json({ id });
});

// 서버를 먼저 띄우고 레디스 연결은 뒤에서 시도한다.
// 저장소가 죽어 있어도 프로세스는 살아 있고, 준비 상태만 /readyz 로 알린다.
const server = app.listen(PORT, () => {
  log('info', 'listening', { port: PORT, version: VERSION });
});

connectRedis().catch((e) => log('error', 'redis connect failed', { detail: String(e) }));

// SIGTERM 을 처리하지 않으면 PID 1 은 종료 신호를 무시한다 (M02 · M15).
process.on('SIGTERM', () => {
  log('info', 'SIGTERM received, draining');
  server.close(() => process.exit(0));
});

// course/labs/scripts/k6-capacity.js
// M37 용량 산정 부하. 램프업 → 정상 → 스파이크 → 회복의 네 구간을 한 번에 돈다.
//
//   k6 run course/labs/scripts/k6-capacity.js
//   k6 run -e PEAK=400 -e STEADY=150 course/labs/scripts/k6-capacity.js
//   k6 run -e PROFILE=steady -e RPS=200 -e DURATION=2m ...   (한 구간만)
//
// 멈추는 방법: Ctrl-C. 백그라운드면 `pkill -f k6-capacity`.
//
// 한 엔드포인트만 반복해서 때리면 안 되는 이유 (책 20.2.3) —
// 읽기만 반복하면 캐시가 다 맞고, 쓰기만 반복하면 실제와 다른 잠금 경합이 생긴다.
// 실제 트래픽의 비율을 흉내 내야 병목이 실제와 같은 자리에 나타난다.
// 아래 가중치는 이 앱의 접근 로그에서 나온 비율을 가정한 값이다 —
// **자기 서비스의 실제 비율로 바꿔서 쓴다.**
import http from 'k6/http';
import { check } from 'k6';
import { Trend, Rate } from 'k6/metrics';

const HOST = __ENV.HOST || 'journal.local';
const PORT = __ENV.PORT || '18080';
const BASE = `http://localhost:${PORT}`;

const STEADY = Number(__ENV.STEADY || 150);
const PEAK = Number(__ENV.PEAK || 400);
const PROFILE = __ENV.PROFILE || 'full';
const RPS = Number(__ENV.RPS || STEADY);
const DURATION = __ENV.DURATION || '2m';

// 엔드포인트별 지연을 따로 잰다. 전체 P99 만 보면 어느 경로가 느린지 모른다.
const dList = new Trend('lat_list', true);
const dWrite = new Trend('lat_write', true);
const dStatic = new Trend('lat_static', true);
const failRate = new Rate('req_failed_custom');

const full = {
  // ① 램프업 — 어디서 꺾이는지 본다. 계단으로 올려야 꺾인 지점을 짚을 수 있다.
  rampup: {
    executor: 'ramping-arrival-rate',
    startRate: 20,
    timeUnit: '1s',
    preAllocatedVUs: 50,
    maxVUs: 400,
    stages: [
      { target: 50, duration: '30s' },
      { target: 100, duration: '30s' },
      { target: STEADY, duration: '30s' },
    ],
  },
  // ② 정상 — 램프업이 끝난 뒤 같은 부하를 유지하며 안정 상태를 잰다.
  steady: {
    executor: 'constant-arrival-rate',
    rate: STEADY,
    timeUnit: '1s',
    duration: '90s',
    preAllocatedVUs: 60,
    maxVUs: 400,
    startTime: '90s',
  },
  // ③ 스파이크 — 짧고 급한 부하. 오토스케일링이 따라오지 못하는 구간이다.
  spike: {
    executor: 'constant-arrival-rate',
    rate: PEAK,
    timeUnit: '1s',
    duration: '30s',
    preAllocatedVUs: 120,
    maxVUs: 600,
    startTime: '180s',
  },
  // ④ 회복 — 스파이크 뒤에 원래대로 돌아오는가. 여기가 안 돌아오면 무언가 새고 있다.
  recover: {
    executor: 'constant-arrival-rate',
    rate: STEADY,
    timeUnit: '1s',
    duration: '60s',
    preAllocatedVUs: 60,
    maxVUs: 400,
    startTime: '210s',
  },
};

const single = {
  one: {
    executor: 'constant-arrival-rate',
    rate: RPS,
    timeUnit: '1s',
    duration: DURATION,
    preAllocatedVUs: 80,
    maxVUs: 600,
  },
};

export const options = {
  scenarios: PROFILE === 'full' ? full : single,
  // 임계값을 넘으면 k6 가 종료 코드 99 로 끝난다 — CI 에서 그대로 게이트가 된다.
  thresholds: {
    http_req_failed: ['rate<0.01'],
    'lat_list': ['p(99)<500'],
  },
};

export default function () {
  const params = { headers: { Host: HOST }, tags: {} };
  const r = Math.random();

  if (r < 0.70) {
    // 70% — 목록 읽기. 대부분의 트래픽이 읽기다.
    const res = http.get(`${BASE}/api/entries`, { ...params, tags: { ep: 'list' } });
    dList.add(res.timings.duration);
    failRate.add(res.status !== 200);
    check(res, { 'list 200': (x) => x.status === 200 });
  } else if (r < 0.85) {
    // 15% — 쓰기. 레디스에 실제로 쓴다.
    const res = http.post(
      `${BASE}/api/entries`,
      JSON.stringify({ text: `load ${Date.now()}` }),
      { headers: { Host: HOST, 'Content-Type': 'application/json' }, tags: { ep: 'write' } },
    );
    dWrite.add(res.timings.duration);
    failRate.add(res.status >= 400);
    check(res, { 'write 2xx': (x) => x.status >= 200 && x.status < 300 });
  } else {
    // 15% — 정적 파일. 같은 인그레스를 지나지만 다른 백엔드다.
    const res = http.get(`${BASE}/`, { ...params, tags: { ep: 'static' } });
    dStatic.add(res.timings.duration);
    failRate.add(res.status !== 200);
    check(res, { 'static 200': (x) => x.status === 200 });
  }
}

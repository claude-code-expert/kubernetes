// course/labs/scripts/k6-rampup.js
// M17 오토스케일링 실습용 부하. 인그레스를 통해 저널 API 를 호출한다.
//
//   k6 run course/labs/scripts/k6-rampup.js            기본 (약 120 rps, 5분)
//   RPS=40 DURATION=3m k6 run .../k6-rampup.js         약하게
//
// 멈추는 방법: Ctrl-C. k6 는 포그라운드로 돌며 끝나면 요약을 찍는다.
// 백그라운드로 띄웠다면 `pkill -f k6-rampup`.
//
// rps 를 고정하는 이유 — VU(가상 사용자) 수만 정하면 앱이 빨라질수록 요청이 늘어난다.
// 파드가 늘어 응답이 빨라지면 부하도 같이 커져서, HPA 가 무엇에 반응했는지 흐려진다.
// 요청률을 고정해야 "같은 부하에 파드가 몇 개 필요한가"를 잴 수 있다.
import http from 'k6/http';
import { check } from 'k6';

const RPS = Number(__ENV.RPS || 120);
const DURATION = __ENV.DURATION || '5m';
const HOST = __ENV.HOST || 'journal.local';
const PORT = __ENV.PORT || '18080';

export const options = {
  scenarios: {
    steady: {
      executor: 'constant-arrival-rate',
      rate: RPS,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: 20,
      maxVUs: 100,
    },
  },
  thresholds: {
    // 오토스케일링이 늦으면 여기서 드러난다. 실패해도 부하는 계속 돈다.
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const r = http.get(`http://localhost:${PORT}/api/entries`, { headers: { Host: HOST } });
  check(r, { 'status 200': (x) => x.status === 200 });
}

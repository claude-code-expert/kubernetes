// course/labs/scripts/k6-red.js
// M20 RED 질의 실습용 부하. 두 앱에 섞어 넣고, 일부러 느린 요청과 에러를 만든다.
//
//   kubectl -n apps port-forward svc/order-api 18082:8080 &
//   k6 run -e DURATION=3m course/labs/scripts/k6-red.js
//
// 멈추는 방법: Ctrl-C (포그라운드). 백그라운드면 `pkill -f k6-red`.
// port-forward 도 함께 정리한다: `pkill -f 'port-forward.*18082'`
import http from 'k6/http';

const DURATION = __ENV.DURATION || '3m';
const ORDER = `http://localhost:${__ENV.ORDER_PORT || '18082'}`;
const JOURNAL_PORT = __ENV.JOURNAL_PORT || '18080';

export const options = {
  scenarios: {
    // 정상 트래픽 — RED 의 R(요청률)과 D(지연)의 기준선을 만든다
    normal: {
      executor: 'constant-arrival-rate',
      rate: 30, timeUnit: '1s', duration: DURATION,
      preAllocatedVUs: 20, maxVUs: 60, exec: 'normal',
    },
    // 느린 요청 — 히스토그램 꼬리를 만든다. P50 은 그대로인데 P99 만 오른다
    slow: {
      executor: 'constant-arrival-rate',
      rate: 2, timeUnit: '1s', duration: DURATION,
      preAllocatedVUs: 10, maxVUs: 40, exec: 'slow',
    },
    // 에러 — RED 의 E
    errors: {
      executor: 'constant-arrival-rate',
      rate: 3, timeUnit: '1s', duration: DURATION,
      preAllocatedVUs: 5, maxVUs: 20, exec: 'errors',
    },
  },
};

export function normal() {
  http.get(`${ORDER}/api/orders`);
  http.get(`http://localhost:${JOURNAL_PORT}/api/entries`, { headers: { Host: 'journal.local' } });
}
export function slow() {
  http.get(`${ORDER}/api/chaos/slow?ms=800`);
}
export function errors() {
  http.get(`${ORDER}/api/chaos/error?rate=0.7`);
}

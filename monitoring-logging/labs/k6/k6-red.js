// RED 질의·알림 실습용 부하. 두 앱에 섞어 넣고, 일부러 느린 요청과 에러를 만든다.
//
//   kubectl -n apps    port-forward svc/order-api   18082:8080 &
//   kubectl -n journal port-forward svc/journal-api 18083:8080 &
//   k6 run -e DURATION=3m labs/k6/k6-red.js
//
// 멈추기: Ctrl-C (포그라운드). 백그라운드로 돌렸다면 pkill -f k6-red
import http from 'k6/http';

const DURATION = __ENV.DURATION || '3m';
const ORDER = `http://localhost:${__ENV.ORDER_PORT || '18082'}`;
const JOURNAL = `http://localhost:${__ENV.JOURNAL_PORT || '18083'}`;

export const options = {
  scenarios: {
    // 정상 트래픽: R(요청률)과 D(지연)의 기준선
    normal: {
      executor: 'constant-arrival-rate',
      rate: 30, timeUnit: '1s', duration: DURATION,
      preAllocatedVUs: 20, maxVUs: 60, exec: 'normal',
    },
    // 느린 요청 800ms: 히스토그램 꼬리. P50 은 그대로인데 P99 만 오른다
    slow: {
      executor: 'constant-arrival-rate',
      rate: 2, timeUnit: '1s', duration: DURATION,
      preAllocatedVUs: 10, maxVUs: 40, exec: 'slow',
    },
    // 에러: 70% 확률로 500
    errors: {
      executor: 'constant-arrival-rate',
      rate: 3, timeUnit: '1s', duration: DURATION,
      preAllocatedVUs: 5, maxVUs: 20, exec: 'errors',
    },
  },
};

export function normal() {
  http.get(`${ORDER}/api/orders`);
  http.get(`${JOURNAL}/api/entries`);
}
export function slow() {
  http.get(`${ORDER}/api/chaos/slow?ms=800`);
}
export function errors() {
  http.get(`${ORDER}/api/chaos/error?rate=0.7`);
}

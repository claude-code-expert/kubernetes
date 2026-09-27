// 메트릭 라벨을 만드는 순수 함수. 서버에서 분리한 이유는 하나다 — 테스트하기 위해서다.
// 이 두 함수가 틀리면 M19~M21 의 대시보드와 알림이 조용히 잘못된 값을 그린다.

// uri 라벨에 실제 경로를 그대로 넣으면 안 된다. /api/entries/123 같은 값이
// 요청마다 새 시계열을 만들어 카디널리티가 폭발한다 (M19 8절).
// 라우트 패턴으로 정규화하고, 모르는 경로는 하나로 몰아넣는다.
const KNOWN = ['/healthz', '/readyz', '/metrics', '/api/entries'];

export function normalizeUri(path: string): string {
  return KNOWN.includes(path) ? path : 'other';
}

export function outcomeOf(status: number): string {
  if (status < 200) return 'INFORMATIONAL';
  if (status < 300) return 'SUCCESS';
  if (status < 400) return 'REDIRECTION';
  if (status < 500) return 'CLIENT_ERROR';
  return 'SERVER_ERROR';
}

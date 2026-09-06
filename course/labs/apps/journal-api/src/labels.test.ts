import { test } from 'node:test';
import assert from 'node:assert/strict';
import { normalizeUri, outcomeOf } from './labels.js';

test('알려진 경로는 그대로 둔다', () => {
  assert.equal(normalizeUri('/api/entries'), '/api/entries');
  assert.equal(normalizeUri('/healthz'), '/healthz');
});

test('모르는 경로는 other 하나로 몰아넣는다 — 카디널리티 폭발 방지', () => {
  assert.equal(normalizeUri('/api/entries/12345'), 'other');
  assert.equal(normalizeUri('/api/entries/67890'), 'other');
  // 서로 다른 두 요청이 같은 라벨이 되는 것이 목적이다
  assert.equal(normalizeUri('/x/1'), normalizeUri('/x/2'));
});

test('상태 코드를 결과 구간으로 접는다', () => {
  assert.equal(outcomeOf(200), 'SUCCESS');
  assert.equal(outcomeOf(204), 'SUCCESS');
  assert.equal(outcomeOf(301), 'REDIRECTION');
  assert.equal(outcomeOf(404), 'CLIENT_ERROR');
  assert.equal(outcomeOf(503), 'SERVER_ERROR');
});

test('경계값 — 구간의 시작과 끝', () => {
  assert.equal(outcomeOf(199), 'INFORMATIONAL');
  assert.equal(outcomeOf(299), 'SUCCESS');
  assert.equal(outcomeOf(499), 'CLIENT_ERROR');
  assert.equal(outcomeOf(500), 'SERVER_ERROR');
});


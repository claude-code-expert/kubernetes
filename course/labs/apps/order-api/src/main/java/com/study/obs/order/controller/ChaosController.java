package com.study.obs.order.controller;

import java.util.Map;
import java.util.Random;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 대시보드와 알림 실습용 지연·에러 생성기.
 * 06~07단계에서 이 엔드포인트로 그래프를 움직인다.
 */
@RestController
@RequestMapping("/api/chaos")
public class ChaosController {

    private static final long MAX_SLEEP_MS = 5_000L;

    private final Random random = new Random();

    @GetMapping("/slow")
    public Map<String, Object> slow(@RequestParam(defaultValue = "500") long ms)
            throws InterruptedException {
        long sleepMs = Math.min(ms, MAX_SLEEP_MS);
        Thread.sleep(sleepMs);
        return Map.of("sleptMs", sleepMs);
    }

    @GetMapping("/error")
    public ResponseEntity<Map<String, Object>> error(
            @RequestParam(defaultValue = "0.5") double rate) {
        if (random.nextDouble() < rate) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("failed", true));
        }
        return ResponseEntity.ok(Map.of("failed", false));
    }
}

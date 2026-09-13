package com.study.obs.order.domain;

import java.time.Instant;
import java.util.UUID;

public record Order(String id, String item, int quantity, Instant createdAt) {

    public static Order create(String item, int quantity) {
        return new Order(UUID.randomUUID().toString(), item, quantity, Instant.now());
    }
}

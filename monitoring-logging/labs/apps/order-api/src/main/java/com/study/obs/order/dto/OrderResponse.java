package com.study.obs.order.dto;

import com.study.obs.order.domain.Order;
import java.time.Instant;

public record OrderResponse(String id, String item, int quantity, Instant createdAt) {

    public static OrderResponse from(Order order) {
        return new OrderResponse(order.id(), order.item(), order.quantity(), order.createdAt());
    }
}

package com.study.obs.order.common;

import java.time.Instant;

public record ApiResponse<T>(T data, String message, Instant timestamp) {

    public static <T> ApiResponse<T> success(T data, String message) {
        return new ApiResponse<>(data, message, Instant.now());
    }
}

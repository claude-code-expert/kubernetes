package com.study.obs.order.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

public record OrderCreateRequest(
        @NotBlank String item,
        @Min(1) int quantity
) {
}

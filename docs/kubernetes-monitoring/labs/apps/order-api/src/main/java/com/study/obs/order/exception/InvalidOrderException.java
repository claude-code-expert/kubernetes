package com.study.obs.order.exception;

public class InvalidOrderException extends RuntimeException {

    public InvalidOrderException(int quantity) {
        super("허용 범위를 넘는 주문 수량입니다: " + quantity);
    }
}

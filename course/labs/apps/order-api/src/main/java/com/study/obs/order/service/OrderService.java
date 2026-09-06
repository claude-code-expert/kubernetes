package com.study.obs.order.service;

import com.study.obs.order.domain.Order;
import com.study.obs.order.dto.OrderCreateRequest;
import com.study.obs.order.dto.OrderResponse;
import com.study.obs.order.exception.InvalidOrderException;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;

@Service
public class OrderService {

    private static final int MAX_QUANTITY = 100;

    private final Map<String, Order> store = new ConcurrentHashMap<>();
    private final Random random = new Random();

    private final Counter createdCounter;
    private final Counter rejectedCounter;
    private final Timer processingTimer;

    public OrderService(MeterRegistry registry) {
        this.createdCounter = Counter.builder("orders.created")
                .description("생성에 성공한 주문 수")
                .tag("channel", "api")
                .register(registry);

        this.rejectedCounter = Counter.builder("orders.rejected")
                .description("검증에 걸려 거부된 주문 수")
                .tag("reason", "quantity_exceeded")
                .register(registry);

        this.processingTimer = Timer.builder("orders.processing")
                .description("주문 처리에 걸린 시간")
                .publishPercentileHistogram()
                .register(registry);

        Gauge.builder("orders.stored", store, Map::size)
                .description("메모리에 보관 중인 주문 수")
                .register(registry);
    }

    public OrderResponse create(OrderCreateRequest request) {
        return processingTimer.record(() -> {
            simulateWork();
            if (request.quantity() > MAX_QUANTITY) {
                rejectedCounter.increment();
                throw new InvalidOrderException(request.quantity());
            }
            Order order = Order.create(request.item(), request.quantity());
            store.put(order.id(), order);
            createdCounter.increment();
            return OrderResponse.from(order);
        });
    }

    public Optional<OrderResponse> findById(String id) {
        return Optional.ofNullable(store.get(id)).map(OrderResponse::from);
    }

    public List<OrderResponse> findAll() {
        return store.values().stream().map(OrderResponse::from).toList();
    }

    private void simulateWork() {
        try {
            Thread.sleep(random.nextLong(20, 120));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}

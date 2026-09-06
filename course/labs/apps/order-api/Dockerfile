# order-api — Spring Boot 4.1.0 / JDK 21.
# M19 에서 두 번째 실습 앱으로 들어온다. journal-api(Node) 와 달리 JVM 이라
# 기동이 느리고 메모리를 많이 쓴다 — 그 차이가 관측 파트의 소재다.
#
# 베이스 이미지를 다이제스트까지 고정한다. `21-jre` 같은 태그는 움직이는 포인터라
# (M03) 반년 뒤에 다른 이미지를 받는다. 실제로 이 Dockerfile 은 그 때문에 한 번 깨졌다 —
# 베이스가 우분투 기반으로 바뀌면서 UID 1000 에 ubuntu 사용자가 생겼고,
# `useradd -u 1000` 이 "UID 1000 is not unique" 로 실패했다.
# 2026-09-05 확인 — 실습 당일 hub.docker.com/_/eclipse-temurin 에서 다시 확인하라.

FROM eclipse-temurin@sha256:85f00967bcc624fc19fa9c2cf124ea426a5363898e267141726f31f358c2e14b AS builder
WORKDIR /build
COPY . .
RUN ./gradlew bootJar --no-daemon
# 스프링 부트 계층 추출. 의존성과 애플리케이션 코드를 다른 레이어로 나눠
# 소스만 고쳤을 때 무거운 의존성 레이어가 캐시에 남게 한다 (M04 의 그 원리다).
RUN cp build/libs/*.jar app.jar \
 && java -Djarmode=tools -jar app.jar extract --layers --launcher --destination extracted

FROM eclipse-temurin@sha256:7a65df4b22d2de92d4e04056e884f3b9122d70b21e2847fd66084278bd0ce037
WORKDIR /app
# UID 1000 은 베이스 이미지가 이미 쓰고 있다. 충돌하지 않는 값을 골라 명시한다.
RUN useradd -u 10001 -m app
USER 10001
COPY --from=builder /build/extracted/dependencies/ ./
COPY --from=builder /build/extracted/spring-boot-loader/ ./
COPY --from=builder /build/extracted/snapshot-dependencies/ ./
COPY --from=builder /build/extracted/application/ ./
# 컨테이너 메모리 제한(M16 의 limits)의 70% 를 힙 상한으로 삼는다.
# 이 옵션이 없으면 JVM 이 호스트 전체 메모리를 기준으로 힙을 잡아 OOMKilled 가 난다.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70.0"
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]

# Dockerfile — 문서 10.2 절의 Dockerfile 을 그대로 쓰되,
# 로컬에 JDK 가 없어도 빌드되도록 빌더 스테이지를 앞에 둔다.
FROM eclipse-temurin:17-jdk AS builder
WORKDIR /build
COPY . .
RUN ./gradlew bootJar --no-daemon

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=builder /build/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

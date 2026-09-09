FROM eclipse-temurin:21-jdk AS builder
WORKDIR /build
COPY . .
RUN ./gradlew bootJar --no-daemon
RUN cp build/libs/*.jar app.jar \
 && java -Djarmode=tools -jar app.jar extract --layers --launcher --destination extracted

FROM eclipse-temurin:21-jre
WORKDIR /app
RUN useradd -u 1000 -m app
USER 1000
COPY --from=builder /build/extracted/dependencies/ ./
COPY --from=builder /build/extracted/spring-boot-loader/ ./
COPY --from=builder /build/extracted/snapshot-dependencies/ ./
COPY --from=builder /build/extracted/application/ ./
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70.0"
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]

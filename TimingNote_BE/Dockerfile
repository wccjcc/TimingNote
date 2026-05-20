FROM eclipse-temurin:17-jdk AS builder
WORKDIR /app

COPY gradlew gradlew.bat settings.gradle build.gradle ./
COPY gradle ./gradle
RUN chmod +x ./gradlew

# Resolve dependencies early for better layer caching.
RUN ./gradlew --no-daemon dependencies

COPY src ./src
RUN ./gradlew --no-daemon clean bootJar

FROM eclipse-temurin:17-jre
WORKDIR /app

COPY --from=builder /app/build/libs/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

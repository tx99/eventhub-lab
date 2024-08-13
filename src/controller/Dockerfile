# Build stage
FROM maven:3.8.4-openjdk-11-slim AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Run stage
FROM openjdk:11-jre-slim

WORKDIR /app

# Copy the built artifact from the build stage
COPY --from=build /app/target/controller-0.0.1-SNAPSHOT.jar app.jar

# Set environment variables for logging
ENV JAVA_TOOL_OPTIONS="-Dspring.output.ansi.enabled=ALWAYS"
ENV LOGGING_LEVEL_COM_BOOKSTORE_CONTROLLER=INFO

EXPOSE 8089

ENTRYPOINT ["java", "-jar", "app.jar"]
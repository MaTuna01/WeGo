# WeGo 최소 서버 이미지. VM에 JDK를 깔지 않도록 빌드도 컨테이너 안에서 함
# 빌드: docker build -t wego-api .   (wegoBackEnd 폴더에서)

# 1단계: 빌드(JDK)
FROM eclipse-temurin:21-jdk AS build
WORKDIR /workspace
# 의존성만 먼저 받아 두면 소스만 바뀔 때 이 층을 다시 쓰므로 빌드가 빨라짐
COPY gradlew settings.gradle build.gradle ./
COPY gradle gradle
RUN ./gradlew --no-daemon dependencies > /dev/null
COPY src src
# 테스트는 PR 품질 게이트(./gradlew test)에서 돌리므로 이미지 빌드에서는 생략
RUN ./gradlew --no-daemon bootJar -x test

# 2단계: 실행(JRE)
FROM eclipse-temurin:21-jre
RUN groupadd --system wego && useradd --system --gid wego --no-create-home wego
WORKDIR /app
COPY --from=build /workspace/build/libs/app.jar app.jar
# root가 아닌 사용자로 실행
USER wego
EXPOSE 8080
# 컨테이너 메모리 한도의 75%까지 힙 사용, 메모리 부족이면 바로 종료해서 재시작되게 함
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError" \
    TZ=Asia/Seoul
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

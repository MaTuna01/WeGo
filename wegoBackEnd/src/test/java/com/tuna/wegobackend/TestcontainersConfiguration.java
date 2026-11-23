package com.tuna.wegobackend;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * 테스트용 PostgreSQL(PostGIS) 컨테이너
 * - 컨텍스트를 띄우는 테스트에서 @Import로 씀. 접속 정보는 @ServiceConnection이 datasource에 넣음
 * - 배포와 같은 이미지(멀티 아키텍처라 Apple Silicon에서도 뜸). 로컬에 Docker가 떠 있어야 함
 */
@TestConfiguration(proxyBeanMethods = false)
public class TestcontainersConfiguration {

    static final DockerImageName POSTGIS = DockerImageName.parse("imresamu/postgis:17-3.5")
            .asCompatibleSubstituteFor("postgres");

    @Bean
    @ServiceConnection
    PostgreSQLContainer postgres() {
        return new PostgreSQLContainer(POSTGIS);
    }
}

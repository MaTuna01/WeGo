package com.tuna.wegobackend;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest
@Import(TestcontainersConfiguration.class)
class WegoBackEndApplicationTests {

    @Autowired
    JdbcTemplate jdbc;

    @Test
    void contextLoads() {
    }

    @Test
    @DisplayName("Flyway가 V1까지 적용하고 PostGIS 함수를 쓸 수 있다")
    void migratesAndEnablesPostgis() {
        Integer applied = jdbc.queryForObject(
                "SELECT count(*) FROM flyway_schema_history WHERE version = '1' AND success", Integer.class);
        assertThat(applied).isEqualTo(1);

        // 서울시청과 대전시청 사이 직선거리(약 140km)
        Double meters = jdbc.queryForObject(
                "SELECT ST_Distance(ST_MakePoint(126.9780, 37.5665)::geography, ST_MakePoint(127.3845, 36.3504)::geography)",
                Double.class);
        assertThat(meters).isBetween(130_000.0, 150_000.0);
    }
}

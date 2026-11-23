package com.tuna.wegobackend.station;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.tuna.wegobackend.TestcontainersConfiguration;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(TestcontainersConfiguration.class)
class StationRepositoryTest {

    private static final Instant NOW = Instant.parse("2026-11-23T00:00:00Z");

    @Autowired
    StationRepository repository;

    @Autowired
    JdbcTemplate jdbc;

    private static StationEntity entity(String id, BikeOperator operator, String sourceId) {
        return StationEntity.firstSeen(new Station(id, id, operator, 37.5665, 126.9780, 10), sourceId, NOW);
    }

    @Test
    @DisplayName("저장한 정류장을 그대로 읽고, 운영사는 코드로 저장한다")
    void savesAndReads() {
        repository.saveAndFlush(entity("ST-1", BikeOperator.TTAREUNGYI, "ST-1"));

        var found = repository.findById("ST-1").orElseThrow();
        assertThat(found.toStation()).isEqualTo(new Station("ST-1", "ST-1", BikeOperator.TTAREUNGYI, 37.5665, 126.9780, 10));
        assertThat(found.getFirstSeenAt()).isEqualTo(NOW);
        assertThat(jdbc.queryForObject("SELECT operator FROM stations WHERE id = 'ST-1'", String.class)).isEqualTo("ttareungyi");
    }

    @Test
    @DisplayName("위도, 경도로 location(geography)을 DB가 계산한다")
    void computesLocation() {
        repository.saveAndFlush(entity("ST-1", BikeOperator.TTAREUNGYI, "ST-1"));

        // 서울시청 좌표에서 대전시청까지 약 140km
        Double meters = jdbc.queryForObject(
                "SELECT ST_Distance(location, ST_MakePoint(127.3845, 36.3504)::geography) FROM stations WHERE id = 'ST-1'",
                Double.class);
        assertThat(meters).isBetween(130_000.0, 150_000.0);
    }

    @Test
    @DisplayName("같은 운영사의 같은 원본 ID는 두 번 저장할 수 없다")
    void uniqueSourceIdPerOperator() {
        repository.saveAndFlush(entity("ST-1", BikeOperator.TTAREUNGYI, "1"));
        repository.saveAndFlush(entity("TS-1", BikeOperator.TASHU, "1")); // 운영사가 다르면 괜찮음

        assertThatThrownBy(() -> repository.saveAndFlush(entity("ST-2", BikeOperator.TTAREUNGYI, "1")))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    @DisplayName("운영사별 조회와 활성 정류장 조회")
    void findsByOperatorAndActive() {
        var removed = entity("ST-2", BikeOperator.TTAREUNGYI, "ST-2");
        removed.markRemoved(NOW);
        repository.saveAllAndFlush(List.of(
                entity("ST-1", BikeOperator.TTAREUNGYI, "ST-1"), removed, entity("TS-1", BikeOperator.TASHU, "1")));

        assertThat(repository.findByOperator(BikeOperator.TTAREUNGYI))
                .extracting(StationEntity::getId).containsExactlyInAnyOrder("ST-1", "ST-2");
        assertThat(repository.findByRemovedAtIsNull())
                .extracting(StationEntity::getId).containsExactlyInAnyOrder("ST-1", "TS-1");
    }
}

package com.tuna.wegobackend.station;

import static org.assertj.core.api.Assertions.assertThat;

import com.tuna.wegobackend.TestcontainersConfiguration;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.context.annotation.Import;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(TestcontainersConfiguration.class)
class StationListServiceTest {

    private static final Instant NOW = Instant.parse("2026-11-23T00:00:00Z");

    @Autowired
    StationRepository repository;

    private final JsonMapper jsonMapper = JsonMapper.builder().build();
    private StationListService service;

    @BeforeEach
    void setUp() {
        service = new StationListService(repository, jsonMapper);
    }

    private static Station station(String id, Integer docks) {
        return new Station(id, "정류장 " + id, BikeOperator.TTAREUNGYI, 37.5271, 126.9329, docks);
    }

    private void save(Station... stations) {
        for (Station station : stations) {
            repository.save(StationEntity.firstSeen(station, station.id(), NOW));
        }
        repository.flush();
    }

    private JsonNode body() {
        return jsonMapper.readTree(service.current().orElseThrow().body());
    }

    @Test
    @DisplayName("활성 정류장이 없으면 비어 있다")
    void emptyWhenNoStations() {
        assertThat(service.current()).isEmpty();
    }

    @Test
    @DisplayName("응답 본문을 계약 모양으로 만든다")
    void buildsContractBody() {
        save(station("ST-1", 15), station("ST-2", null));

        JsonNode first = body().get("stations").get(0);

        assertThat(body().get("stations")).hasSize(2);
        assertThat(first.get("id").asString()).isEqualTo("ST-1");
        assertThat(first.get("name").asString()).isEqualTo("정류장 ST-1");
        assertThat(first.get("operator").asString()).isEqualTo("ttareungyi");
        assertThat(first.get("latitude").asDouble()).isEqualTo(37.5271);
        assertThat(first.get("longitude").asDouble()).isEqualTo(126.9329);
        assertThat(first.get("dockCount").asInt()).isEqualTo(15);
        assertThat(body().get("stations").get(1).get("dockCount").isNull()).isTrue();
        // 잔여 대수, 저장용 시각은 계약에 없음
        assertThat(first.has("availableBikes")).isFalse();
        assertThat(first.has("lastSeenAt")).isFalse();
    }

    @Test
    @DisplayName("빠진 정류장은 내려주지 않는다")
    void excludesRemoved() {
        save(station("ST-1", 1));
        var removed = StationEntity.firstSeen(station("ST-2", 1), "ST-2", NOW);
        removed.markRemoved(NOW);
        repository.saveAndFlush(removed);

        assertThat(body().get("stations")).hasSize(1);
        assertThat(body().get("stations").get(0).get("id").asString()).isEqualTo("ST-1");
    }

    @Test
    @DisplayName("목록은 ID 순(문자 코드 순)으로 정렬한다")
    void sortsById() {
        save(station("ST-3", 1), station("ST-10", 1), station("ST-1", 1), station("ST-2", 1));

        var ids = new ArrayList<String>();
        body().get("stations").forEach(node -> ids.add(node.get("id").asString()));
        assertThat(ids).containsExactly("ST-1", "ST-10", "ST-2", "ST-3");
    }

    @Test
    @DisplayName("ETag는 약한 ETag 형식이고, 내용이 같으면 같고 바뀌면 달라진다")
    void etagIsContentBased() {
        save(station("ST-1", 10), station("ST-2", 10));
        String first = service.current().orElseThrow().etag();
        String again = service.current().orElseThrow().etag();

        repository.findById("ST-2").orElseThrow().seen(station("ST-2", 11), NOW);
        repository.flush();
        String changed = service.current().orElseThrow().etag();

        assertThat(first).matches("W/\"[0-9a-f]{32}\"");
        assertThat(again).isEqualTo(first);
        assertThat(changed).isNotEqualTo(first);
    }

    @Test
    @DisplayName("마지막 확인 시각만 바뀌면 ETag는 그대로다")
    void etagIgnoresLastSeen() {
        save(station("ST-1", 10));
        String first = service.current().orElseThrow().etag();

        repository.findById("ST-1").orElseThrow().seen(station("ST-1", 10), NOW.plusSeconds(3600));
        repository.flush();

        assertThat(service.current().orElseThrow().etag()).isEqualTo(first);
    }

    @Test
    @DisplayName("같은 목록이면 예전 메모리 방식과 같은 본문을 만든다(배포 후 앱이 다시 받지 않음)")
    void sameBodyAsBefore() {
        save(station("ST-2", null), station("ST-1", 15));

        String json = new String(service.current().orElseThrow().body(), StandardCharsets.UTF_8);

        assertThat(json).isEqualTo("{\"stations\":["
                + "{\"id\":\"ST-1\",\"name\":\"정류장 ST-1\",\"operator\":\"ttareungyi\",\"latitude\":37.5271,\"longitude\":126.9329,\"dockCount\":15},"
                + "{\"id\":\"ST-2\",\"name\":\"정류장 ST-2\",\"operator\":\"ttareungyi\",\"latitude\":37.5271,\"longitude\":126.9329,\"dockCount\":null}"
                + "]}");
    }
}

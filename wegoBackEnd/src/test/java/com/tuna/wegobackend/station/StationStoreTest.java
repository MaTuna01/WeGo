package com.tuna.wegobackend.station;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

class StationStoreTest {

    private final JsonMapper jsonMapper = JsonMapper.builder().build();
    private final StationStore store = new StationStore(jsonMapper);

    private static Station station(String id, Integer docks) {
        return new Station(id, "정류장 " + id, BikeOperator.TTAREUNGYI, 37.5271, 126.9329, docks);
    }

    @Test
    @DisplayName("처음에는 비어 있다")
    void emptyAtFirst() {
        assertThat(store.isEmpty()).isTrue();
        assertThat(store.current()).isEmpty();
    }

    @Test
    @DisplayName("응답 본문을 계약 모양으로 만든다")
    void buildsContractBody() {
        store.replace(List.of(station("ST-1", 15), station("ST-2", null)), Instant.EPOCH);

        JsonNode body = jsonMapper.readTree(store.current().orElseThrow().body());
        JsonNode first = body.get("stations").get(0);

        assertThat(body.get("stations")).hasSize(2);
        assertThat(first.get("id").asString()).isEqualTo("ST-1");
        assertThat(first.get("name").asString()).isEqualTo("정류장 ST-1");
        assertThat(first.get("operator").asString()).isEqualTo("ttareungyi");
        assertThat(first.get("latitude").asDouble()).isEqualTo(37.5271);
        assertThat(first.get("longitude").asDouble()).isEqualTo(126.9329);
        assertThat(first.get("dockCount").asInt()).isEqualTo(15);
        assertThat(body.get("stations").get(1).get("dockCount").isNull()).isTrue();
        // 잔여 대수는 1.0 계약에 없음
        assertThat(first.has("availableBikes")).isFalse();
        assertThat(new String(store.current().orElseThrow().body(), StandardCharsets.UTF_8)).contains("정류장");
    }

    @Test
    @DisplayName("ETag는 약한 ETag 형식이고, 순서만 다른 목록이면 같고 내용이 바뀌면 달라진다")
    void etagIsStableAndContentBased() {
        store.replace(List.of(station("ST-1", 10), station("ST-2", 10)), Instant.EPOCH);
        String first = store.current().orElseThrow().etag();

        store.replace(List.of(station("ST-2", 10), station("ST-1", 10)), Instant.now());
        String reordered = store.current().orElseThrow().etag();

        store.replace(List.of(station("ST-1", 10), station("ST-2", 11)), Instant.now());
        String changed = store.current().orElseThrow().etag();

        assertThat(first).matches("W/\"[0-9a-f]{32}\"");
        assertThat(reordered).isEqualTo(first);
        assertThat(changed).isNotEqualTo(first);
    }

    @Test
    @DisplayName("목록은 ID 순으로 정렬해 둔다")
    void sortsById() {
        store.replace(List.of(station("ST-3", 1), station("ST-1", 1), station("ST-2", 1)), Instant.EPOCH);
        assertThat(store.current().orElseThrow().stations()).extracting(Station::id).containsExactly("ST-1", "ST-2", "ST-3");
    }
}

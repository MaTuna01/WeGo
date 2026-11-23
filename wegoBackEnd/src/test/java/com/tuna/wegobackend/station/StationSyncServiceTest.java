package com.tuna.wegobackend.station;

import static org.assertj.core.api.Assertions.assertThat;

import com.tuna.wegobackend.TestcontainersConfiguration;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.context.annotation.Import;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import({TestcontainersConfiguration.class, StationSyncService.class})
class StationSyncServiceTest {

    private static final Instant T0 = Instant.parse("2026-11-23T00:00:00Z");
    private static final Instant T1 = Instant.parse("2026-11-23T06:00:00Z");
    private static final Instant T2 = Instant.parse("2026-11-23T12:00:00Z");

    @Autowired
    StationSyncService syncService;

    @Autowired
    StationRepository repository;

    @Autowired
    TestEntityManager em;

    private static Station seoul(String id, String name) {
        return new Station(id, name, BikeOperator.TTAREUNGYI, 37.5, 126.9, 10);
    }

    private static Station tashu(String id) {
        return new Station(id, id, BikeOperator.TASHU, 36.35, 127.38, null);
    }

    /** 실제 갱신처럼 한 번 반영할 때마다 DB에 쓰고 영속성 컨텍스트를 비움 */
    private StationSyncService.Result sync(BikeOperator operator, List<Station> stations, Instant now) {
        var result = syncService.sync(operator, stations, now);
        em.flush();
        em.clear();
        return result;
    }

    private StationEntity find(String id) {
        return repository.findById(id).orElseThrow();
    }

    @Test
    @DisplayName("처음 받으면 모두 추가한다")
    void addsNew() {
        var result = sync(BikeOperator.TTAREUNGYI, List.of(seoul("ST-1", "A"), seoul("ST-2", "B")), T0);

        assertThat(result).isEqualTo(new StationSyncService.Result(2, 0, 0, 0));
        assertThat(find("ST-1").getSourceId()).isEqualTo("ST-1");
        assertThat(find("ST-1").getFirstSeenAt()).isEqualTo(T0);
    }

    @Test
    @DisplayName("바뀐 값은 반영하고, 그대로인 정류장은 마지막 확인 시각만 바꾼다")
    void updatesChanged() {
        sync(BikeOperator.TTAREUNGYI, List.of(seoul("ST-1", "A"), seoul("ST-2", "B")), T0);

        var result = sync(BikeOperator.TTAREUNGYI, List.of(seoul("ST-1", "A 1번출구"), seoul("ST-2", "B")), T1);

        assertThat(result).isEqualTo(new StationSyncService.Result(0, 1, 0, 1));
        assertThat(find("ST-1").getName()).isEqualTo("A 1번출구");
        assertThat(find("ST-1").getUpdatedAt()).isEqualTo(T1);
        assertThat(find("ST-2").getUpdatedAt()).isEqualTo(T0);
        assertThat(find("ST-2").getLastSeenAt()).isEqualTo(T1);
    }

    @Test
    @DisplayName("목록에서 빠지면 지우지 않고 표시만 하고, 다시 나타나면 표시를 지운다")
    void marksRemovedAndBack() {
        sync(BikeOperator.TTAREUNGYI, List.of(seoul("ST-1", "A"), seoul("ST-2", "B")), T0);

        var removed = sync(BikeOperator.TTAREUNGYI, List.of(seoul("ST-1", "A")), T1);
        assertThat(removed).isEqualTo(new StationSyncService.Result(0, 0, 1, 1));
        assertThat(find("ST-2").getRemovedAt()).isEqualTo(T1);
        assertThat(repository.findActiveStations()).extracting(Station::id).containsExactly("ST-1");

        var back = sync(BikeOperator.TTAREUNGYI, List.of(seoul("ST-1", "A"), seoul("ST-2", "B")), T2);
        assertThat(back).isEqualTo(new StationSyncService.Result(0, 1, 0, 1));
        assertThat(find("ST-2").isActive()).isTrue();
        assertThat(find("ST-2").getFirstSeenAt()).isEqualTo(T0);
    }

    @Test
    @DisplayName("반영하는 운영사의 정류장만 건드린다")
    void touchesOnlyThatOperator() {
        sync(BikeOperator.TTAREUNGYI, List.of(seoul("ST-1", "A")), T0);
        sync(BikeOperator.TASHU, List.of(tashu("TS-1")), T0);

        // 따릉이 목록에 타슈 정류장이 없어도 타슈 정류장은 빠짐 처리되지 않음
        var result = sync(BikeOperator.TTAREUNGYI, List.of(seoul("ST-1", "A")), T1);

        assertThat(result.removed()).isZero();
        assertThat(find("TS-1").isActive()).isTrue();
        assertThat(find("TS-1").getLastSeenAt()).isEqualTo(T0);
    }

    @Test
    @DisplayName("같은 ID가 두 번 오면 먼저 온 것만 쓴다")
    void ignoresDuplicateIds() {
        var result = sync(BikeOperator.TTAREUNGYI, List.of(seoul("ST-1", "A"), seoul("ST-1", "A 중복")), T0);

        assertThat(result.added()).isEqualTo(1);
        assertThat(find("ST-1").getName()).isEqualTo("A");
    }
}

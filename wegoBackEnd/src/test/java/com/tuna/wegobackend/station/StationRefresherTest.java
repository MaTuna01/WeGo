package com.tuna.wegobackend.station;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.function.Supplier;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class StationRefresherTest {

    private static final Instant NOW = Instant.parse("2026-11-19T00:00:00Z");

    /** 호출할 때마다 정해 둔 결과를 차례로 돌려주는 가짜 수집기 */
    static class FakeSource implements StationSource {
        final BikeOperator operator;
        final Deque<Supplier<List<Station>>> results = new ArrayDeque<>();
        boolean enabled = true;
        int calls;

        FakeSource(BikeOperator operator) {
            this.operator = operator;
        }

        FakeSource then(Supplier<List<Station>> result) {
            results.add(result);
            return this;
        }

        FakeSource thenFail() {
            return then(() -> {
                throw new StationFetchException(operator.code() + " API 호출 실패");
            });
        }

        @Override
        public BikeOperator operator() {
            return operator;
        }

        @Override
        public List<Station> fetchAll() {
            calls++;
            return results.removeFirst().get();
        }

        @Override
        public boolean isEnabled() {
            return enabled;
        }
    }

    private static FakeSource seoul() {
        return new FakeSource(BikeOperator.TTAREUNGYI);
    }

    private static FakeSource tashu() {
        return new FakeSource(BikeOperator.TASHU);
    }

    private static Station station(String id) {
        return station(id, BikeOperator.TTAREUNGYI);
    }

    private static Station station(String id, BikeOperator operator) {
        return new Station(id, id, operator, 37.5, 126.9, 10);
    }

    private final StationStore store = new StationStore(tools.jackson.databind.json.JsonMapper.builder().build());
    private final StationSyncService syncService = mock(StationSyncService.class);

    {
        when(syncService.sync(any(), anyList(), any())).thenReturn(new StationSyncService.Result(0, 0, 0, 0));
    }

    private StationRefresher refresher(StationSource... sources) {
        return new StationRefresher(List.of(sources), store, syncService, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private List<String> storedIds() {
        return store.current().orElseThrow().stations().stream().map(Station::id).toList();
    }

    @Test
    @DisplayName("받으면 목록과 갱신 시각을 바꾼다")
    void replacesOnSuccess() {
        var refresher = refresher(seoul().then(() -> List.of(station("A"), station("B"))));

        assertThat(refresher.refresh()).isTrue();

        var snapshot = store.current().orElseThrow();
        assertThat(snapshot.stations()).extracting(Station::id).containsExactly("A", "B");
        assertThat(snapshot.updatedAt()).isEqualTo(NOW);
    }

    @Test
    @DisplayName("실패하거나 빈 목록, 예상 못 한 예외면 이전 목록을 유지한다")
    void keepsPreviousOnFailure() {
        var source = seoul()
                .then(() -> List.of(station("A")))
                .thenFail()
                .then(List::of)
                .then(() -> {
                    throw new IllegalStateException("unexpected");
                });
        var refresher = refresher(source);

        refresher.refresh();
        assertThat(refresher.refresh()).isFalse();
        assertThat(refresher.refresh()).isFalse();
        assertThat(refresher.refresh()).isFalse();

        assertThat(storedIds()).containsExactly("A");
    }

    @Test
    @DisplayName("운영사별로 받은 목록을 합쳐 저장한다")
    void mergesOperators() {
        var refresher = refresher(
                seoul().then(() -> List.of(station("A"))),
                tashu().then(() -> List.of(station("T1", BikeOperator.TASHU), station("T2", BikeOperator.TASHU))));

        assertThat(refresher.refresh()).isTrue();

        assertThat(storedIds()).containsExactlyInAnyOrder("A", "T1", "T2");
    }

    @Test
    @DisplayName("한 운영사가 실패하면 그 운영사만 이전 목록을 쓰고 다른 운영사는 갱신한다")
    void keepsFailedOperatorOnly() {
        var refresher = refresher(
                seoul().then(() -> List.of(station("A"))).then(() -> List.of(station("A"), station("B"))),
                tashu().then(() -> List.of(station("T1", BikeOperator.TASHU))).thenFail());

        refresher.refresh();
        assertThat(refresher.refresh()).isTrue();

        assertThat(storedIds()).containsExactlyInAnyOrder("A", "B", "T1");
    }

    @Test
    @DisplayName("모든 운영사가 실패하면 저장본을 바꾸지 않는다")
    void keepsStoreWhenAllFail() {
        var refresher = refresher(
                seoul().then(() -> List.of(station("A"))).thenFail(),
                tashu().then(() -> List.of(station("T1", BikeOperator.TASHU))).thenFail());

        refresher.refresh();
        var before = store.current().orElseThrow();

        assertThat(refresher.refresh()).isFalse();
        assertThat(store.current().orElseThrow()).isSameAs(before);
    }

    @Test
    @DisplayName("인증키가 없는 운영사는 건너뛰고 나머지만 받는다")
    void skipsDisabledOperator() {
        var seoul = seoul().then(() -> List.of(station("A")));
        var tashu = tashu();
        tashu.enabled = false;

        assertThat(refresher(seoul, tashu).refresh()).isTrue();

        assertThat(tashu.calls).isZero();
        assertThat(storedIds()).containsExactly("A");
    }

    @Test
    @DisplayName("모든 운영사가 꺼져 있으면 수집하지 않는다")
    void skipsWhenAllDisabled() {
        var source = seoul();
        source.enabled = false;

        assertThat(refresher(source).refresh()).isFalse();
        assertThat(source.calls).isZero();
        assertThat(store.isEmpty()).isTrue();
    }

    @Test
    @DisplayName("재시도는 한 번도 받지 못한 운영사만 한다")
    void retriesOnlyMissingOperators() {
        var seoul = seoul().then(() -> List.of(station("A")));
        var tashu = tashu().thenFail().then(() -> List.of(station("T1", BikeOperator.TASHU)));
        var refresher = refresher(seoul, tashu);

        refresher.refresh();      // 따릉이 성공, 타슈 실패
        refresher.retryMissing(); // 타슈만 다시 시도해 성공
        refresher.retryMissing(); // 둘 다 받았으므로 호출하지 않음

        assertThat(seoul.calls).isEqualTo(1);
        assertThat(tashu.calls).isEqualTo(2);
        assertThat(storedIds()).containsExactlyInAnyOrder("A", "T1");
    }

    @Test
    @DisplayName("받은 운영사만 DB에 반영한다")
    void savesOnlyReceivedOperatorsToDb() {
        var seoulStations = List.of(station("A"));
        var refresher = refresher(seoul().then(() -> seoulStations), tashu().thenFail());

        refresher.refresh();

        verify(syncService).sync(BikeOperator.TTAREUNGYI, seoulStations, NOW);
        verify(syncService, never()).sync(eq(BikeOperator.TASHU), anyList(), any());
    }

    @Test
    @DisplayName("DB 반영이 실패해도 메모리 목록은 갱신한다")
    void updatesStoreWhenDbFails() {
        when(syncService.sync(any(), anyList(), any())).thenThrow(new IllegalStateException("db down"));
        var refresher = refresher(seoul().then(() -> List.of(station("A"))));

        assertThat(refresher.refresh()).isTrue();

        assertThat(storedIds()).containsExactly("A");
    }
}

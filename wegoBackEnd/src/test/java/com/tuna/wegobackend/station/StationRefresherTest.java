package com.tuna.wegobackend.station;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.function.Supplier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** DB 반영(StationSyncService)은 Mockito로 대신하고, 언제 무엇을 반영하는지만 확인 */
class StationRefresherTest {

    private static final Instant NOW = Instant.parse("2026-11-19T00:00:00Z");
    private static final StationSyncService.Result OK = new StationSyncService.Result(0, 0, 0, 0);

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
        return new Station(id, id, BikeOperator.TTAREUNGYI, 37.5, 126.9, 10);
    }

    private static Station tashuStation(String id) {
        return new Station(id, id, BikeOperator.TASHU, 36.35, 127.38, null);
    }

    private final StationSyncService syncService = mock(StationSyncService.class);

    @BeforeEach
    void stubSync() {
        when(syncService.sync(any(), anyList(), any())).thenReturn(OK);
    }

    private StationRefresher refresher(StationSource... sources) {
        return new StationRefresher(List.of(sources), syncService, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    @DisplayName("받으면 받은 시각으로 DB에 반영한다")
    void savesOnSuccess() {
        var stations = List.of(station("A"), station("B"));
        var refresher = refresher(seoul().then(() -> stations));

        assertThat(refresher.refresh()).isTrue();

        verify(syncService).sync(BikeOperator.TTAREUNGYI, stations, NOW);
    }

    @Test
    @DisplayName("받기 실패, 빈 목록, 예상 못 한 예외면 DB를 건드리지 않는다")
    void skipsDbOnFailure() {
        var source = seoul()
                .thenFail()
                .then(List::of)
                .then(() -> {
                    throw new IllegalStateException("unexpected");
                });
        var refresher = refresher(source);

        assertThat(refresher.refresh()).isFalse();
        assertThat(refresher.refresh()).isFalse();
        assertThat(refresher.refresh()).isFalse();

        verify(syncService, never()).sync(any(), anyList(), any());
    }

    @Test
    @DisplayName("운영사마다 따로 반영하고, 한 운영사가 실패해도 다른 운영사는 반영한다")
    void savesEachOperatorSeparately() {
        var seoulStations = List.of(station("A"));
        var refresher = refresher(seoul().then(() -> seoulStations), tashu().thenFail());

        assertThat(refresher.refresh()).isTrue();

        verify(syncService).sync(BikeOperator.TTAREUNGYI, seoulStations, NOW);
        verify(syncService, never()).sync(eq(BikeOperator.TASHU), anyList(), any());
    }

    @Test
    @DisplayName("인증키가 없는 운영사는 건너뛰고 나머지만 받는다")
    void skipsDisabledOperator() {
        var seoul = seoul().then(() -> List.of(station("A")));
        var tashu = tashu();
        tashu.enabled = false;

        assertThat(refresher(seoul, tashu).refresh()).isTrue();

        assertThat(tashu.calls).isZero();
        verify(syncService, never()).sync(eq(BikeOperator.TASHU), anyList(), any());
    }

    @Test
    @DisplayName("모든 운영사가 꺼져 있으면 수집하지 않는다")
    void skipsWhenAllDisabled() {
        var source = seoul();
        source.enabled = false;

        assertThat(refresher(source).refresh()).isFalse();
        assertThat(source.calls).isZero();
        verify(syncService, never()).sync(any(), anyList(), any());
    }

    @Test
    @DisplayName("재시도는 이번 실행에서 아직 반영하지 못한 운영사만 한다")
    void retriesOnlyMissingOperators() {
        var seoul = seoul().then(() -> List.of(station("A")));
        var tashu = tashu().thenFail().then(() -> List.of(tashuStation("T1")));
        var refresher = refresher(seoul, tashu);

        refresher.refresh();      // 따릉이 성공, 타슈 실패
        refresher.retryMissing(); // 타슈만 다시 시도해 성공
        refresher.retryMissing(); // 둘 다 반영했으므로 호출하지 않음

        assertThat(seoul.calls).isEqualTo(1);
        assertThat(tashu.calls).isEqualTo(2);
        verify(syncService).sync(eq(BikeOperator.TASHU), anyList(), any());
    }

    @Test
    @DisplayName("DB 반영이 실패하면 반영하지 못한 것으로 보고 재시도한다")
    void retriesWhenDbFails() {
        when(syncService.sync(any(), anyList(), any()))
                .thenThrow(new IllegalStateException("db down"))
                .thenReturn(OK);
        var source = seoul().then(() -> List.of(station("A"))).then(() -> List.of(station("A")));
        var refresher = refresher(source);

        assertThat(refresher.refresh()).isFalse(); // 받았지만 DB 실패
        refresher.retryMissing();                  // 다시 받아 반영
        refresher.retryMissing();                  // 이미 반영했으므로 호출하지 않음

        assertThat(source.calls).isEqualTo(2);
        verify(syncService, times(2)).sync(any(), anyList(), any());
    }
}

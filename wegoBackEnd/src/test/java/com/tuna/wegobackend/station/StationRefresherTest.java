package com.tuna.wegobackend.station;

import static org.assertj.core.api.Assertions.assertThat;

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
        final Deque<Supplier<List<Station>>> results = new ArrayDeque<>();
        boolean enabled = true;
        int calls;

        FakeSource then(Supplier<List<Station>> result) {
            results.add(result);
            return this;
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

    private static Station station(String id) {
        return new Station(id, id, BikeOperator.TTAREUNGYI, 37.5, 126.9, 10);
    }

    private final StationStore store = new StationStore();

    private StationRefresher refresher(StationSource source) {
        return new StationRefresher(source, store, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    @DisplayName("받으면 목록과 갱신 시각을 바꾼다")
    void replacesOnSuccess() {
        var refresher = refresher(new FakeSource().then(() -> List.of(station("A"), station("B"))));

        assertThat(refresher.refresh()).isTrue();

        var snapshot = store.current().orElseThrow();
        assertThat(snapshot.stations()).extracting(Station::id).containsExactly("A", "B");
        assertThat(snapshot.updatedAt()).isEqualTo(NOW);
    }

    @Test
    @DisplayName("실패하거나 빈 목록, 예상 못 한 예외면 이전 목록을 유지한다")
    void keepsPreviousOnFailure() {
        var source = new FakeSource()
                .then(() -> List.of(station("A")))
                .then(() -> {
                    throw new StationFetchException("서울시 API HTTP 500");
                })
                .then(List::of)
                .then(() -> {
                    throw new IllegalStateException("unexpected");
                });
        var refresher = refresher(source);

        refresher.refresh();
        assertThat(refresher.refresh()).isFalse();
        assertThat(refresher.refresh()).isFalse();
        assertThat(refresher.refresh()).isFalse();

        assertThat(store.current().orElseThrow().stations()).extracting(Station::id).containsExactly("A");
    }

    @Test
    @DisplayName("인증키가 없으면 수집하지 않는다")
    void skipsWhenDisabled() {
        var source = new FakeSource();
        source.enabled = false;

        assertThat(refresher(source).refresh()).isFalse();
        assertThat(source.calls).isZero();
        assertThat(store.isEmpty()).isTrue();
    }

    @Test
    @DisplayName("재시도는 한 번도 받지 못했을 때만 한다")
    void retriesOnlyWhenEmpty() {
        var source = new FakeSource()
                .then(() -> {
                    throw new StationFetchException("서울시 API 호출 실패");
                })
                .then(() -> List.of(station("A")));
        var refresher = refresher(source);

        refresher.retryIfEmpty(); // 실패
        refresher.retryIfEmpty(); // 성공
        refresher.retryIfEmpty(); // 이미 있으므로 호출하지 않음

        assertThat(source.calls).isEqualTo(2);
        assertThat(store.isEmpty()).isFalse();
    }
}

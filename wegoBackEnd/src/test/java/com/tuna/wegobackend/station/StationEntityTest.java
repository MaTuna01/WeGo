package com.tuna.wegobackend.station;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class StationEntityTest {

    private static final Instant T0 = Instant.parse("2026-11-23T00:00:00Z");
    private static final Instant T1 = Instant.parse("2026-11-23T06:00:00Z");
    private static final Instant T2 = Instant.parse("2026-11-23T12:00:00Z");

    private static Station station(String name, double latitude, Integer dockCount) {
        return new Station("ST-1", name, BikeOperator.TTAREUNGYI, latitude, 126.9, dockCount);
    }

    @Test
    @DisplayName("처음 받으면 받은 시각으로 모든 시각을 채운다")
    void firstSeen() {
        var entity = StationEntity.firstSeen(station("여의도역", 37.5, 10), "ST-1", T0);

        assertThat(entity.getFirstSeenAt()).isEqualTo(T0);
        assertThat(entity.getLastSeenAt()).isEqualTo(T0);
        assertThat(entity.getUpdatedAt()).isEqualTo(T0);
        assertThat(entity.isActive()).isTrue();
        assertThat(entity.toStation()).isEqualTo(station("여의도역", 37.5, 10));
    }

    @Test
    @DisplayName("값이 같으면 마지막 확인 시각만 바꾼다")
    void seenUnchanged() {
        var entity = StationEntity.firstSeen(station("여의도역", 37.5, 10), "ST-1", T0);

        assertThat(entity.seen(station("여의도역", 37.5, 10), T1)).isFalse();

        assertThat(entity.getLastSeenAt()).isEqualTo(T1);
        assertThat(entity.getUpdatedAt()).isEqualTo(T0);
    }

    @Test
    @DisplayName("이름, 좌표, 거치대 수가 바뀌면 반영하고 수정 시각을 바꾼다")
    void seenChanged() {
        var entity = StationEntity.firstSeen(station("여의도역", 37.5, 10), "ST-1", T0);

        assertThat(entity.seen(station("여의도역 1번출구", 37.6, null), T1)).isTrue();

        assertThat(entity.toStation()).isEqualTo(station("여의도역 1번출구", 37.6, null));
        assertThat(entity.getUpdatedAt()).isEqualTo(T1);
        assertThat(entity.getFirstSeenAt()).isEqualTo(T0);
    }

    @Test
    @DisplayName("빠지면 표시만 하고, 다시 나타나면 표시를 지운다")
    void removedAndBack() {
        var entity = StationEntity.firstSeen(station("여의도역", 37.5, 10), "ST-1", T0);

        assertThat(entity.markRemoved(T1)).isTrue();
        assertThat(entity.markRemoved(T2)).isFalse(); // 이미 빠짐
        assertThat(entity.getRemovedAt()).isEqualTo(T1);
        assertThat(entity.isActive()).isFalse();

        assertThat(entity.seen(station("여의도역", 37.5, 10), T2)).isTrue();
        assertThat(entity.isActive()).isTrue();
        assertThat(entity.getUpdatedAt()).isEqualTo(T2);
    }
}

package com.tuna.wegobackend.station;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import org.springframework.stereotype.Component;

/**
 * 메모리 정류장 목록(1.0은 DB 없음). 갱신은 목록 전체를 한 번에 바꿔서 읽는 쪽이 중간 상태를 보지 않게 함
 */
@Component
public class StationStore {

    /** 한 번 갱신한 결과 */
    public record Snapshot(List<Station> stations, Instant updatedAt) {
    }

    private final AtomicReference<Snapshot> current = new AtomicReference<>();

    /** 아직 한 번도 받지 못했으면 empty */
    public Optional<Snapshot> current() {
        return Optional.ofNullable(current.get());
    }

    public boolean isEmpty() {
        return current.get() == null;
    }

    public void replace(List<Station> stations, Instant updatedAt) {
        current.set(new Snapshot(List.copyOf(stations), updatedAt));
    }
}

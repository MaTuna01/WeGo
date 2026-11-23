package com.tuna.wegobackend.station;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 한 운영사에서 받은 정류장 목록을 stations 테이블에 반영
 * - 갱신에 성공한 운영사만 부름(실패한 운영사의 행은 건드리지 않음)
 * - 새 정류장 추가, 바뀐 값 반영, 목록에서 빠진 정류장은 지우지 않고 removed_at 표시, 다시 나타나면 해제
 * - 운영사 하나를 한 트랜잭션으로 반영해서 중간에 실패하면 그 운영사는 반영 전 상태로 남음
 */
@Service
public class StationSyncService {

    /**
     * 반영 결과(로그용)
     *
     * @param added     새로 추가
     * @param changed   이름, 좌표, 거치대 수가 바뀌었거나 다시 나타남
     * @param removed   이번에 목록에서 빠짐
     * @param unchanged 그대로(last_seen_at만 갱신)
     */
    public record Result(int added, int changed, int removed, int unchanged) {
    }

    private final StationRepository repository;

    public StationSyncService(StationRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public Result sync(BikeOperator operator, List<Station> stations, Instant now) {
        Map<String, StationEntity> existing = repository.findByOperator(operator).stream()
                .collect(Collectors.toMap(StationEntity::getId, Function.identity()));

        List<StationEntity> newEntities = new ArrayList<>();
        Set<String> seenIds = new HashSet<>();
        int changed = 0;
        int unchanged = 0;
        for (Station station : stations) {
            if (!seenIds.add(station.id())) {
                continue; // 같은 ID가 두 번 오면 먼저 온 것만 씀
            }
            StationEntity entity = existing.get(station.id());
            if (entity == null) {
                newEntities.add(StationEntity.firstSeen(station, sourceIdOf(station), now));
            } else if (entity.seen(station, now)) {
                changed++;
            } else {
                unchanged++;
            }
        }

        int removed = 0;
        for (StationEntity entity : existing.values()) {
            if (!seenIds.contains(entity.getId()) && entity.markRemoved(now)) {
                removed++;
            }
        }

        // 기존 행의 변경은 트랜잭션 끝에 변경 감지로 저장됨
        repository.saveAll(newEntities);
        return new Result(newEntities.size(), changed, removed, unchanged);
    }

    /** 운영사 원본 ID. 따릉이는 앱에 주는 ID와 같음(타슈는 #67에서 실제 ID를 보고 정함) */
    private static String sourceIdOf(Station station) {
        return station.id();
    }
}

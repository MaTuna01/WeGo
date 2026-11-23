package com.tuna.wegobackend.station;

import java.time.Clock;
import java.time.Instant;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 정류장 목록 주기 갱신(운영사별)
 * - 서버 시작 직후 한 번, 이후 refresh-interval(기본 6시간)마다 모든 운영사를 받아 DB(stations)에 반영
 * - 운영사마다 따로 받고 따로 반영. 실패하거나 빈 목록이면 그 운영사는 DB의 이전 목록 유지
 * - GET /stations는 DB를 읽으므로 서버를 다시 켜도 운영사 API와 상관없이 마지막 목록으로 응답
 * - 이번 실행에서 아직 반영하지 못한 운영사만 retry-interval(기본 1분)마다 다시 시도
 * - 인증키가 없는 운영사는 건너뜀
 */
@Slf4j
@Component
public class StationRefresher {

    private final List<StationSource> sources;
    private final StationSyncService syncService;
    private final Clock clock;
    /** 이번 실행에서 한 번이라도 DB 반영까지 마친 운영사 */
    private final Set<BikeOperator> received = EnumSet.noneOf(BikeOperator.class);
    /** 인증키 없음 경고를 이미 남긴 운영사(한 번만 남김) */
    private final Set<BikeOperator> warnedDisabled = EnumSet.noneOf(BikeOperator.class);

    @Autowired
    public StationRefresher(List<StationSource> sources, StationSyncService syncService) {
        this(sources, syncService, Clock.systemUTC());
    }

    /** 테스트에서 시각을 고정할 때 */
    StationRefresher(List<StationSource> sources, StationSyncService syncService, Clock clock) {
        this.sources = List.copyOf(sources);
        this.syncService = syncService;
        this.clock = clock;
    }

    @Scheduled(fixedDelayString = "${wego.stations.refresh-interval}")
    public void scheduledRefresh() {
        refresh();
    }

    @Scheduled(fixedDelayString = "${wego.stations.retry-interval}", initialDelayString = "${wego.stations.retry-interval}")
    public void retryMissing() {
        List<StationSource> missing = sources.stream()
                .filter(source -> !hasReceived(source.operator()))
                .toList();
        if (!missing.isEmpty()) {
            refresh(missing);
        }
    }

    /** 모든 운영사를 받음. 하나라도 반영했으면 true */
    public boolean refresh() {
        return refresh(sources);
    }

    // 정기 갱신과 재시도가 겹쳐도 같은 운영사를 동시에 반영하지 않게 함
    private synchronized boolean refresh(List<StationSource> targets) {
        boolean updated = false;
        for (StationSource source : targets) {
            updated |= refreshOne(source);
        }
        return updated;
    }

    /** 한 운영사를 받아 DB에 반영. 반영까지 마쳤으면 true */
    private boolean refreshOne(StationSource source) {
        BikeOperator operator = source.operator();
        if (!source.isEnabled()) {
            if (warnedDisabled.add(operator)) {
                log.warn("{} 정류장 수집 꺼짐(인증키 없음)", operator.code());
            }
            return false;
        }
        long startedAt = System.nanoTime();
        List<Station> stations;
        try {
            stations = source.fetchAll();
        } catch (StationFetchException e) {
            log.error("{} 정류장 받기 실패, DB의 이전 목록 유지: {}", operator.code(), e.getMessage());
            return false;
        } catch (RuntimeException e) {
            // 예상 못 한 오류도 스케줄러를 멈추지 않게 잡음(메시지에 키가 있을 수 있어 종류만 기록)
            log.error("{} 정류장 받기 중 예외, DB의 이전 목록 유지: {}", operator.code(), e.getClass().getName());
            return false;
        }
        if (stations.isEmpty()) {
            log.warn("{} 정류장 응답이 비어 있어 DB의 이전 목록 유지", operator.code());
            return false;
        }

        try {
            StationSyncService.Result result = syncService.sync(operator, stations, Instant.now(clock));
            received.add(operator);
            log.info("{} 정류장 {}곳 반영: 추가 {}, 변경 {}, 빠짐 {}, 그대로 {} ({}ms)",
                    operator.code(), stations.size(), result.added(), result.changed(), result.removed(), result.unchanged(),
                    (System.nanoTime() - startedAt) / 1_000_000);
            return true;
        } catch (RuntimeException e) {
            // DB 오류. 다음 재시도(아직 한 번도 못 했으면 1분 뒤) 또는 정기 갱신 때 다시 반영
            log.error("{} 정류장 DB 반영 실패, DB의 이전 목록 유지: {}", operator.code(), e.getClass().getName());
            return false;
        }
    }

    private synchronized boolean hasReceived(BikeOperator operator) {
        return received.contains(operator);
    }
}

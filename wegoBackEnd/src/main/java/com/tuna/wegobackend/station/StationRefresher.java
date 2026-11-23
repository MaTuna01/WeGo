package com.tuna.wegobackend.station;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 정류장 목록 주기 갱신(운영사별)
 * - 서버 시작 직후 한 번, 이후 refresh-interval(기본 6시간)마다 모든 운영사를 받음
 * - 운영사마다 따로 받고, 실패하거나 빈 목록이면 그 운영사만 이전 목록 유지
 * - 운영사별 마지막 성공 목록을 합쳐 StationStore에 넣음
 * - 한 번도 받지 못한 운영사만 retry-interval(기본 1분)마다 다시 시도
 * - 인증키가 없는 운영사는 건너뜀(모든 운영사가 한 번도 못 받았으면 GET /stations는 503)
 */
@Component
public class StationRefresher {

    private static final Logger log = LoggerFactory.getLogger(StationRefresher.class);

    private final List<StationSource> sources;
    private final StationStore store;
    private final Clock clock;
    /** 운영사별 마지막 성공 목록 */
    private final Map<BikeOperator, List<Station>> lastGood = new EnumMap<>(BikeOperator.class);
    /** 인증키 없음 경고를 이미 남긴 운영사(한 번만 남김) */
    private final Set<BikeOperator> warnedDisabled = EnumSet.noneOf(BikeOperator.class);

    @Autowired
    public StationRefresher(List<StationSource> sources, StationStore store) {
        this(sources, store, Clock.systemUTC());
    }

    /** 테스트에서 시각을 고정할 때 */
    StationRefresher(List<StationSource> sources, StationStore store, Clock clock) {
        this.sources = List.copyOf(sources);
        this.store = store;
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

    /** 모든 운영사를 받음. 하나라도 새로 받았으면 true */
    public boolean refresh() {
        return refresh(sources);
    }

    // 정기 갱신과 재시도가 겹쳐도 lastGood을 동시에 바꾸지 않게 함
    private synchronized boolean refresh(List<StationSource> targets) {
        boolean updated = false;
        for (StationSource source : targets) {
            updated |= refreshOne(source);
        }
        if (updated) {
            List<Station> merged = new ArrayList<>();
            lastGood.values().forEach(merged::addAll);
            store.replace(merged, Instant.now(clock));
        }
        return updated;
    }

    /** 한 운영사를 받아 성공하면 lastGood을 바꿈. 성공 여부를 돌려줌 */
    private boolean refreshOne(StationSource source) {
        BikeOperator operator = source.operator();
        if (!source.isEnabled()) {
            if (warnedDisabled.add(operator)) {
                log.warn("{} 정류장 수집 꺼짐(인증키 없음)", operator.code());
            }
            return false;
        }
        long startedAt = System.nanoTime();
        try {
            List<Station> stations = source.fetchAll();
            if (stations.isEmpty()) {
                log.warn("{} 정류장 응답이 비어 있어 이전 목록 유지", operator.code());
                return false;
            }
            lastGood.put(operator, List.copyOf(stations));
            log.info("{} 정류장 {}곳 갱신 ({}ms)", operator.code(), stations.size(), (System.nanoTime() - startedAt) / 1_000_000);
            return true;
        } catch (StationFetchException e) {
            log.error("{} 정류장 갱신 실패, 이전 목록 유지({}곳): {}", operator.code(), receivedCount(operator), e.getMessage());
            return false;
        } catch (RuntimeException e) {
            // 예상 못 한 오류도 스케줄러를 멈추지 않게 잡음(메시지에 키가 있을 수 있어 종류만 기록)
            log.error("{} 정류장 갱신 중 예외, 이전 목록 유지: {}", operator.code(), e.getClass().getName());
            return false;
        }
    }

    private synchronized boolean hasReceived(BikeOperator operator) {
        return lastGood.containsKey(operator);
    }

    private int receivedCount(BikeOperator operator) {
        return lastGood.getOrDefault(operator, List.of()).size();
    }
}

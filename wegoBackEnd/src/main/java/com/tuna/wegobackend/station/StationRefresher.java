package com.tuna.wegobackend.station;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 정류장 목록 주기 갱신
 * - 서버 시작 직후 한 번, 이후 refresh-interval(기본 6시간)마다 받음
 * - 실패하거나 빈 목록이면 이전 목록 유지
 * - 한 번도 받지 못한 상태면 retry-interval(기본 1분)마다 다시 시도(그동안 GET /stations는 503)
 */
@Component
public class StationRefresher {

    private static final Logger log = LoggerFactory.getLogger(StationRefresher.class);

    private final StationSource source;
    private final StationStore store;
    private final Clock clock;
    private final AtomicBoolean warnedDisabled = new AtomicBoolean();

    @Autowired
    public StationRefresher(StationSource source, StationStore store) {
        this(source, store, Clock.systemUTC());
    }

    /** 테스트에서 시각을 고정할 때 */
    StationRefresher(StationSource source, StationStore store, Clock clock) {
        this.source = source;
        this.store = store;
        this.clock = clock;
    }

    @Scheduled(fixedDelayString = "${wego.stations.refresh-interval}")
    public void scheduledRefresh() {
        refresh();
    }

    @Scheduled(fixedDelayString = "${wego.stations.retry-interval}", initialDelayString = "${wego.stations.retry-interval}")
    public void retryIfEmpty() {
        if (store.isEmpty()) {
            refresh();
        }
    }

    /** 한 번 받아서 성공하면 바꿈. 성공 여부를 돌려줌 */
    public boolean refresh() {
        if (!source.isEnabled()) {
            if (warnedDisabled.compareAndSet(false, true)) {
                log.warn("정류장 수집 꺼짐(서울시 API 인증키 없음). GET /stations는 503으로 응답");
            }
            return false;
        }
        long startedAt = System.nanoTime();
        try {
            List<Station> stations = source.fetchAll();
            if (stations.isEmpty()) {
                log.warn("정류장 응답이 비어 있어 이전 목록 유지");
                return false;
            }
            store.replace(stations, Instant.now(clock));
            log.info("정류장 {}곳 갱신 ({}ms)", stations.size(), (System.nanoTime() - startedAt) / 1_000_000);
            return true;
        } catch (StationFetchException e) {
            log.error("정류장 갱신 실패, 이전 목록 유지: {}", e.getMessage());
            return false;
        } catch (RuntimeException e) {
            // 예상 못 한 오류도 스케줄러를 멈추지 않게 잡음(메시지에 키가 있을 수 있어 종류만 기록)
            log.error("정류장 갱신 중 예외, 이전 목록 유지: {}", e.getClass().getName());
            return false;
        }
    }
}

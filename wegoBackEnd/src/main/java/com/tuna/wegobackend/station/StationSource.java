package com.tuna.wegobackend.station;

import java.util.List;

/**
 * 운영사 정류장 목록 수집(운영사별 어댑터)
 */
public interface StationSource {

    /**
     * 전체 목록을 받음. 일부만 받은 상태로 돌려주지 않고 실패하면 예외
     *
     * @throws StationFetchException 호출 실패, 응답 오류
     */
    List<Station> fetchAll();

    /** 수집할 수 있는 상태인지(인증키 설정 등) */
    boolean isEnabled();
}

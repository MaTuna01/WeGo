package com.tuna.wegobackend.station;

/**
 * 운영사 공통 정류장 모델(GET /stations의 한 항목). 운영사별 어댑터가 이 모양으로 변환
 *
 * @param id        운영사 원본 ID. 앱의 주행 기록이 저장하므로 바꾸지 않음
 * @param dockCount 거치대 수. 모르면 null
 */
public record Station(
        String id,
        String name,
        BikeOperator operator,
        double latitude,
        double longitude,
        Integer dockCount
) {
}

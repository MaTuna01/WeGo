package com.tuna.wegobackend.station;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StationRepository extends JpaRepository<StationEntity, String> {

    /** 운영사의 모든 정류장(빠진 것 포함). 갱신 결과를 반영할 때 씀 */
    List<StationEntity> findByOperator(BikeOperator operator);

    /** 활성 정류장(빠지지 않은 것). 서버 시작 시 메모리 목록 복구용 */
    List<StationEntity> findByRemovedAtIsNull();
}

package com.tuna.wegobackend.station;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface StationRepository extends JpaRepository<StationEntity, String> {

    /** 운영사의 모든 정류장(빠진 것 포함). 갱신 결과를 반영할 때 씀 */
    List<StationEntity> findByOperator(BikeOperator operator);

    /** 활성 정류장(빠지지 않은 것)을 응답 모델로 바로 읽음(엔티티를 만들지 않아 가벼움). GET /stations용 */
    @Query("""
            select new com.tuna.wegobackend.station.Station(s.id, s.name, s.operator, s.latitude, s.longitude, s.dockCount)
            from StationEntity s
            where s.removedAt is null
            """)
    List<Station> findActiveStations();
}

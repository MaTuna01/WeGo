package com.tuna.wegobackend.station;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PostLoad;
import jakarta.persistence.PostPersist;
import jakarta.persistence.Table;
import jakarta.persistence.Transient;
import java.time.Instant;
import java.util.Objects;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.domain.Persistable;

/**
 * 정류장 테이블(stations) 한 행. API 응답 모양은 Station(record)이고, 이 엔티티는 저장과 이력용
 * - location(geography) 컬럼은 DB가 위도, 경도로 계산하므로 매핑하지 않음
 * - 자주 바뀌는 값(잔여 대수)은 두지 않음
 * - ID를 직접 정하므로 Persistable로 새 행인지 알려 줌(그렇지 않으면 저장 전에 행마다 SELECT함)
 */
@Entity
@Table(name = "stations")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class StationEntity implements Persistable<String> {

    @Id
    private String id;

    @Column(nullable = false)
    private BikeOperator operator;

    @Column(nullable = false)
    private String sourceId;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private double latitude;

    @Column(nullable = false)
    private double longitude;

    private Integer dockCount;

    @Column(nullable = false)
    private Instant firstSeenAt;

    @Column(nullable = false)
    private Instant lastSeenAt;

    private Instant removedAt;

    @Column(nullable = false)
    private Instant updatedAt;

    @Transient
    private boolean isNew;

    /**
     * 처음 받은 정류장
     *
     * @param sourceId 운영사 원본 ID(따릉이는 station.id()와 같음)
     */
    public static StationEntity firstSeen(Station station, String sourceId, Instant now) {
        StationEntity entity = new StationEntity();
        entity.id = station.id();
        entity.operator = station.operator();
        entity.sourceId = sourceId;
        entity.firstSeenAt = now;
        entity.copyFrom(station);
        entity.lastSeenAt = now;
        entity.updatedAt = now;
        entity.isNew = true;
        return entity;
    }

    /**
     * 운영사 목록에 다시 있음. 이름, 좌표, 거치대 수가 바뀌었거나 빠졌다가 돌아왔으면 반영하고 true
     * last_seen_at은 바뀐 것이 없어도 갱신함
     */
    public boolean seen(Station station, Instant now) {
        lastSeenAt = now;
        boolean changed = removedAt != null || !sameValues(station);
        if (changed) {
            copyFrom(station);
            removedAt = null;
            updatedAt = now;
        }
        return changed;
    }

    /** 운영사 목록에서 빠짐. 이미 빠진 상태면 그대로 두고 false */
    public boolean markRemoved(Instant now) {
        if (removedAt != null) {
            return false;
        }
        removedAt = now;
        updatedAt = now;
        return true;
    }

    @Override
    public boolean isNew() {
        return isNew;
    }

    @PostLoad
    @PostPersist
    void markNotNew() {
        isNew = false;
    }

    public boolean isActive() {
        return removedAt == null;
    }

    /** API 응답 모델로 변환 */
    public Station toStation() {
        return new Station(id, name, operator, latitude, longitude, dockCount);
    }

    private boolean sameValues(Station station) {
        return name.equals(station.name())
                && latitude == station.latitude()
                && longitude == station.longitude()
                && Objects.equals(dockCount, station.dockCount());
    }

    private void copyFrom(Station station) {
        name = station.name();
        latitude = station.latitude();
        longitude = station.longitude();
        dockCount = station.dockCount();
    }
}

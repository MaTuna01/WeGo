package com.tuna.wegobackend.station.seoul;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * 공공자전거 실시간 대여정보(bikeList) 응답. 숫자도 문자열로 옴
 * 정상: { "rentBikeStatus": { "RESULT": {...}, "row": [...] } }
 * 오류, 데이터 없음: { "RESULT": { "CODE": "INFO-200", ... } } 처럼 최상위에 RESULT만 옴
 */
@JsonIgnoreProperties(ignoreUnknown = true)
record SeoulBikeResponse(
        @JsonProperty("rentBikeStatus") Body rentBikeStatus,
        @JsonProperty("RESULT") Result result
) {

    static final String OK = "INFO-000";
    static final String NO_DATA = "INFO-200";

    /** 본문 안쪽이든 최상위든 있는 쪽의 결과 코드 */
    String code() {
        if (rentBikeStatus != null && rentBikeStatus.result() != null) {
            return rentBikeStatus.result().code();
        }
        return result != null ? result.code() : null;
    }

    List<Row> rows() {
        return rentBikeStatus != null && rentBikeStatus.row() != null ? rentBikeStatus.row() : List.of();
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record Body(
            @JsonProperty("RESULT") Result result,
            @JsonProperty("row") List<Row> row
    ) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record Result(
            @JsonProperty("CODE") String code,
            @JsonProperty("MESSAGE") String message
    ) {
    }

    /** 잔여 대수(parkingBikeTotCnt)는 1.0에서 쓰지 않으므로 받지 않음 */
    @JsonIgnoreProperties(ignoreUnknown = true)
    record Row(
            String stationId,
            String stationName,
            String rackTotCnt,
            String stationLatitude,
            String stationLongitude
    ) {
    }
}

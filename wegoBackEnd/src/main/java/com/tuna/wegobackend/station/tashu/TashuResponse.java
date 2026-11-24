package com.tuna.wegobackend.station.tashu;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * 타슈 Open API 정류장 목록(GET /v1/openapi/station) 응답
 * 정상: { "count": 1375, "next": null, "previous": null, "results": [...] }
 * 오류: { "error_code": "1001", "message": "권한이 없습니다.", "status_code": 400, ... }
 */
@JsonIgnoreProperties(ignoreUnknown = true)
record TashuResponse(
        Integer count,
        String next,
        List<Row> results,
        @JsonProperty("error_code") String errorCode
) {

    List<Row> rows() {
        return results != null ? results : List.of();
    }

    boolean hasNext() {
        return next != null && !next.isBlank();
    }

    /**
     * 정류장 한 곳. 좌표는 문자열이고 x_pos가 위도, y_pos가 경도임(보통과 반대)
     * 받지 않는 값: name_en, name_cn(이름 뒤에 거치대 정보가 붙은 비공식 칸), address,
     * parking_count(현재 대수, 거치대 수보다 많기도 해 신뢰도 낮음)
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    record Row(
            String id,
            String name,
            @JsonProperty("x_pos") String xPos,
            @JsonProperty("y_pos") String yPos
    ) {
    }
}

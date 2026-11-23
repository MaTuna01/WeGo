package com.tuna.wegobackend.station;

import com.fasterxml.jackson.annotation.JsonValue;

/**
 * 공유자전거 운영사. JSON 값은 계약의 operator 문자열(docs/api-contract.md)
 * 값을 추가해도 구버전 앱은 unknown으로 받고 그 정류장만 숨김
 */
public enum BikeOperator {
    TTAREUNGYI("ttareungyi"),
    TASHU("tashu");

    private final String code;

    BikeOperator(String code) {
        this.code = code;
    }

    @JsonValue
    public String code() {
        return code;
    }

    /** 코드로 찾음(DB 값 읽기). 모르는 코드면 예외 */
    public static BikeOperator fromCode(String code) {
        for (BikeOperator operator : values()) {
            if (operator.code.equals(code)) {
                return operator;
            }
        }
        throw new IllegalArgumentException("알 수 없는 운영사 코드: " + code);
    }
}

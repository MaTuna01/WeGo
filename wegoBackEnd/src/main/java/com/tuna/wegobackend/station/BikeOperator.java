package com.tuna.wegobackend.station;

import com.fasterxml.jackson.annotation.JsonValue;

/**
 * 공유자전거 운영사. JSON 값은 계약의 operator 문자열(docs/api-contract.md)
 * 값을 추가해도 구버전 앱은 unknown으로 받고 그 정류장만 숨김
 */
public enum BikeOperator {
    // 따릉이는 원본 ID(ST-123)를 그대로 씀
    TTAREUNGYI("ttareungyi", ""),
    // 타슈 원본 ID(ST0003)는 따릉이와 형식이 비슷해 접두어를 붙임(TS-ST0003)
    TASHU("tashu", "TS-");

    private final String code;
    private final String idPrefix;

    BikeOperator(String code, String idPrefix) {
        this.code = code;
        this.idPrefix = idPrefix;
    }

    @JsonValue
    public String code() {
        return code;
    }

    /** 운영사 원본 ID -> 앱에 주는 ID. 앱의 주행 기록이 저장하므로 규칙을 바꾸지 않음 */
    public String appIdOf(String sourceId) {
        return idPrefix + sourceId;
    }

    /** 앱에 주는 ID -> 운영사 원본 ID */
    public String sourceIdOf(String appId) {
        if (!appId.startsWith(idPrefix)) {
            throw new IllegalArgumentException(code + " 정류장 ID 형식이 아님: " + appId);
        }
        return appId.substring(idPrefix.length());
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

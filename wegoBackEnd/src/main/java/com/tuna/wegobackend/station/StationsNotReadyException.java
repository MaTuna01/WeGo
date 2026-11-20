package com.tuna.wegobackend.station;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.ErrorResponseException;

/**
 * 정류장 목록을 아직 한 번도 받지 못함(503). 앱은 기기 저장본, 앱 내장 목록으로 동작
 */
public class StationsNotReadyException extends ErrorResponseException {

    /** 재시도 간격(StationRefresher 재시도 주기와 맞춤) */
    static final String RETRY_AFTER_SECONDS = "60";

    public StationsNotReadyException() {
        super(HttpStatus.SERVICE_UNAVAILABLE,
                ProblemDetail.forStatusAndDetail(HttpStatus.SERVICE_UNAVAILABLE, "정류장 목록을 아직 받지 못함"),
                null);
        getHeaders().set("Retry-After", RETRY_AFTER_SECONDS);
    }
}

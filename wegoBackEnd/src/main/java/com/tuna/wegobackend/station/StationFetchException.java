package com.tuna.wegobackend.station;

/**
 * 정류장 수집 실패. 메시지에 인증키가 든 URL을 넣지 않도록 원인 예외를 붙이지 않음
 */
public class StationFetchException extends RuntimeException {

    public StationFetchException(String message) {
        super(message);
    }
}

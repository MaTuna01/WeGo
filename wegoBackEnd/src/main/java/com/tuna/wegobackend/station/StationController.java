package com.tuna.wegobackend.station;

import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

/**
 * GET /stations(docs/api-contract.md)
 * - 200: DB의 활성 정류장 목록과 ETag
 * - 304: If-None-Match가 지금 ETag와 같으면 본문 없이
 * - 503: 아직 한 번도 받지 못함(활성 정류장 없음)
 */
@RestController
public class StationController {

    private final StationListService stationListService;

    public StationController(StationListService stationListService) {
        this.stationListService = stationListService;
    }

    @GetMapping("/stations")
    public ResponseEntity<byte[]> stations(@RequestHeader(value = "If-None-Match", required = false) String ifNoneMatch) {
        StationListService.StationList snapshot = stationListService.current().orElseThrow(StationsNotReadyException::new);
        // 앱이 ETag로 매번 확인하므로 중간 캐시는 저장해도 되지만 꼭 다시 확인하게 함
        CacheControl cacheControl = CacheControl.noCache();

        if (matches(ifNoneMatch, snapshot.etag())) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED)
                    .eTag(snapshot.etag())
                    .cacheControl(cacheControl)
                    .build();
        }
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_JSON)
                .eTag(snapshot.etag())
                .cacheControl(cacheControl)
                .body(snapshot.body());
    }

    /** If-None-Match 비교(약한 비교). 여러 값(쉼표), W/ 유무, 와일드카드(*)를 받음 */
    static boolean matches(String ifNoneMatch, String etag) {
        if (ifNoneMatch == null || ifNoneMatch.isBlank()) {
            return false;
        }
        String expected = opaque(etag);
        for (String candidate : ifNoneMatch.split(",")) {
            String tag = candidate.strip();
            if (tag.equals("*") || opaque(tag).equals(expected)) {
                return true;
            }
        }
        return false;
    }

    private static String opaque(String tag) {
        return tag.startsWith("W/") ? tag.substring(2) : tag;
    }
}

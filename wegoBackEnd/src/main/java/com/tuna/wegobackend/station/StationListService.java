package com.tuna.wegobackend.station;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;

/**
 * GET /stations 응답 만들기. 요청마다 DB의 활성 정류장을 읽음(캐시 없음)
 * - 정류장 수천 곳, 앱은 사용자당 최대 1시간에 한 번 확인하므로 매번 읽어도 부담이 작음
 * - 사용자가 늘어 부담이 되면 이 서비스에만 캐시를 붙이면 됨
 */
@Service
public class StationListService {

    /**
     * 응답 본문과 ETag
     *
     * @param body GET /stations 응답 본문(JSON)
     * @param etag 본문 해시로 만든 약한 ETag(W/"..."). Tomcat은 강한 ETag가 붙은 응답을 gzip 압축하지 않으므로 약한 ETag를 씀
     */
    public record StationList(byte[] body, String etag) {
    }

    /** GET /stations 응답 모양(docs/api-contract.md) */
    record StationsResponse(List<Station> stations) {
    }

    private final StationRepository repository;
    private final JsonMapper jsonMapper;

    public StationListService(StationRepository repository, JsonMapper jsonMapper) {
        this.repository = repository;
        this.jsonMapper = jsonMapper;
    }

    /** 활성 정류장이 하나도 없으면(아직 한 번도 받지 못함) empty */
    @Transactional(readOnly = true)
    public Optional<StationList> current() {
        List<Station> stations = repository.findActiveStations();
        if (stations.isEmpty()) {
            return Optional.empty();
        }
        // 운영사 API가 순서만 바꿔 보내도 ETag가 바뀌지 않게 ID 순으로 정렬(DB 정렬 규칙과 무관하게 항상 같은 순서)
        List<Station> sorted = stations.stream().sorted(Comparator.comparing(Station::id)).toList();
        byte[] body = jsonMapper.writeValueAsBytes(new StationsResponse(sorted));
        return Optional.of(new StationList(body, etag(body)));
    }

    private static String etag(byte[] body) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256").digest(body);
            // 앞 16바이트(32자)면 충돌 걱정 없이 충분함
            return "W/\"" + HexFormat.of().formatHex(hash, 0, 16) + "\"";
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 없음", e);
        }
    }
}

package com.tuna.wegobackend.station;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

/**
 * 메모리 정류장 목록(1.0은 DB 없음). 갱신은 목록 전체를 한 번에 바꿔서 읽는 쪽이 중간 상태를 보지 않게 함
 * GET /stations 응답 본문과 ETag는 갱신할 때 한 번만 만들어 두고 요청마다 그대로 씀
 */
@Component
public class StationStore {

    /**
     * 한 번 갱신한 결과
     *
     * @param body GET /stations 응답 본문(JSON)
     * @param etag 본문 해시로 만든 약한 ETag(W/"..."). Tomcat은 강한 ETag가 붙은 응답을 gzip 압축하지 않으므로 약한 ETag를 씀
     */
    public record Snapshot(List<Station> stations, Instant updatedAt, byte[] body, String etag) {
    }

    /** GET /stations 응답 모양(docs/api-contract.md) */
    record StationsResponse(List<Station> stations) {
    }

    private final AtomicReference<Snapshot> current = new AtomicReference<>();
    private final JsonMapper jsonMapper;

    public StationStore(JsonMapper jsonMapper) {
        this.jsonMapper = jsonMapper;
    }

    /** 아직 한 번도 받지 못했으면 empty */
    public Optional<Snapshot> current() {
        return Optional.ofNullable(current.get());
    }

    public boolean isEmpty() {
        return current.get() == null;
    }

    public void replace(List<Station> stations, Instant updatedAt) {
        // 운영사 API가 순서만 바꿔 보내도 ETag가 바뀌지 않게 ID 순으로 정렬
        List<Station> sorted = stations.stream().sorted(Comparator.comparing(Station::id)).toList();
        byte[] body = jsonMapper.writeValueAsBytes(new StationsResponse(sorted));
        current.set(new Snapshot(sorted, updatedAt, body, etag(body)));
    }

    /** 테스트에서 처음 상태로 돌릴 때 */
    void clear() {
        current.set(null);
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

package com.tuna.wegobackend.station.tashu;

import com.tuna.wegobackend.station.BikeOperator;
import com.tuna.wegobackend.station.Station;
import com.tuna.wegobackend.station.StationFetchException;
import com.tuna.wegobackend.station.StationSource;
import java.net.URI;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.json.JsonMapper;

/**
 * 대전 타슈 정류장 수집(타슈 Open API station)
 * - 지금은 한 번에 전체(약 1,400곳)가 오지만, next가 있으면 따라가서 끝까지 받음
 * - 인증키는 api-token 헤더로 보내고, next 주소가 다른 서버를 가리키면 키를 보내지 않고 실패 처리
 * - 앱에 주는 ID는 원본 ID 앞에 운영사 접두어를 붙임(BikeOperator.TASHU.appIdOf)
 */
@Slf4j
@Component
public class TashuClient implements StationSource {

    static final String STATIONS_PATH = "/v1/openapi/station";
    static final String API_TOKEN_HEADER = "api-token";

    // 대전 주변 범위. 위도, 경도가 뒤바뀌거나 엉뚱한 값이면 제외
    private static final double MIN_LATITUDE = 35.9;
    private static final double MAX_LATITUDE = 36.7;
    private static final double MIN_LONGITUDE = 127.1;
    private static final double MAX_LONGITUDE = 127.8;

    private final RestClient restClient;
    private final TashuProperties properties;
    private final JsonMapper jsonMapper;

    public TashuClient(
            @Qualifier("tashuRestClient") RestClient restClient,
            TashuProperties properties,
            JsonMapper jsonMapper
    ) {
        this.restClient = restClient;
        this.properties = properties;
        this.jsonMapper = jsonMapper;
    }

    @Override
    public BikeOperator operator() {
        return BikeOperator.TASHU;
    }

    @Override
    public boolean isEnabled() {
        return properties.hasApiKey();
    }

    @Override
    public List<Station> fetchAll() {
        if (!isEnabled()) {
            throw new StationFetchException("타슈 API 인증키가 없음");
        }
        // 같은 ID가 두 번 오면 먼저 온 것을 씀
        Map<String, Station> stations = new LinkedHashMap<>();
        int skipped = 0;
        URI next = null;

        for (int page = 0; page < properties.maxPages(); page++) {
            TashuResponse response = fetchPage(next);
            if (response.errorCode() != null) {
                throw new StationFetchException("타슈 API 오류 코드: " + response.errorCode());
            }
            for (TashuResponse.Row row : response.rows()) {
                Optional<Station> station = toStation(row);
                if (station.isPresent()) {
                    stations.putIfAbsent(station.get().id(), station.get());
                } else {
                    skipped++;
                }
            }
            if (!response.hasNext()) {
                if (skipped > 0) {
                    log.warn("타슈 정류장 {}건은 값이 잘못되어 제외", skipped);
                }
                return new ArrayList<>(stations.values());
            }
            next = sameServer(response.next());
        }
        // 끝까지 next가 이어졌다면 일부만 받은 것일 수 있으므로 쓰지 않음
        throw new StationFetchException("최대 페이지 수(" + properties.maxPages() + ")를 넘음");
    }

    /** next 주소가 설정한 API 서버와 같을 때만 따라감(다른 서버로 인증키가 나가지 않게) */
    private URI sameServer(String next) {
        URI base = URI.create(properties.baseUrl());
        URI uri;
        try {
            uri = URI.create(next.strip());
        } catch (IllegalArgumentException e) {
            throw new StationFetchException("타슈 API next 주소 형식 오류");
        }
        boolean same = Objects.equals(base.getScheme(), uri.getScheme())
                && Objects.equals(base.getHost(), uri.getHost())
                && base.getPort() == uri.getPort();
        if (!same) {
            throw new StationFetchException("타슈 API next 주소가 다른 서버를 가리킴");
        }
        return uri;
    }

    private TashuResponse fetchPage(URI next) {
        String body;
        try {
            RestClient.RequestHeadersSpec<?> request = next == null
                    ? restClient.get().uri(STATIONS_PATH)
                    : restClient.get().uri(next);
            body = request
                    .header(API_TOKEN_HEADER, properties.apiKey())
                    .retrieve()
                    .body(String.class);
        } catch (RestClientResponseException e) {
            // 오류도 JSON 본문(error_code)으로 오므로 코드가 있으면 함께 남김
            throw new StationFetchException("타슈 API HTTP " + e.getStatusCode().value() + errorCodeOf(e));
        } catch (RestClientException e) {
            throw new StationFetchException("타슈 API 호출 실패: " + e.getClass().getSimpleName());
        }
        if (body == null || body.isBlank()) {
            throw new StationFetchException("타슈 API 응답 본문 없음");
        }
        try {
            return jsonMapper.readValue(body, TashuResponse.class);
        } catch (JacksonException e) {
            throw new StationFetchException("타슈 API 응답 형식 오류");
        }
    }

    private String errorCodeOf(RestClientResponseException e) {
        try {
            String code = jsonMapper.readValue(e.getResponseBodyAsString(), TashuResponse.class).errorCode();
            return code != null && code.matches("[0-9A-Za-z_-]{1,20}") ? " (오류 코드 " + code + ")" : "";
        } catch (JacksonException | IllegalArgumentException ignored) {
            return "";
        }
    }

    /** 공통 모델로 변환. ID, 이름이 없거나 좌표가 대전 범위를 벗어나면 제외 */
    static Optional<Station> toStation(TashuResponse.Row row) {
        String sourceId = trim(row.id());
        String name = trim(row.name());
        Double latitude = parseDouble(row.xPos());
        Double longitude = parseDouble(row.yPos());
        if (sourceId == null || name == null || latitude == null || longitude == null) {
            return Optional.empty();
        }
        if (latitude < MIN_LATITUDE || latitude > MAX_LATITUDE || longitude < MIN_LONGITUDE || longitude > MAX_LONGITUDE) {
            return Optional.empty();
        }
        // 거치대 수는 공식 필드가 없어 null
        return Optional.of(new Station(BikeOperator.TASHU.appIdOf(sourceId), name, BikeOperator.TASHU, latitude, longitude, null));
    }

    private static String trim(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.strip();
    }

    private static Double parseDouble(String value) {
        try {
            return value == null ? null : Double.valueOf(value.strip());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}

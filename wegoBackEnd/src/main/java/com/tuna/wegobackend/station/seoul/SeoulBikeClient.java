package com.tuna.wegobackend.station.seoul;

import com.tuna.wegobackend.station.BikeOperator;
import com.tuna.wegobackend.station.Station;
import com.tuna.wegobackend.station.StationFetchException;
import com.tuna.wegobackend.station.StationSource;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
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
 * 서울시 따릉이 정류장 수집(공공자전거 실시간 대여정보 bikeList)
 * - 한 번에 최대 1,000건이라 페이지를 나눠 받고, 마지막 페이지(1,000건 미만 또는 데이터 없음)에서 멈춤
 * - 인증키가 URL 경로에 들어가므로 예외 메시지, 로그에 URL을 남기지 않음
 * - 응답 Content-Type이 JSON이 아닐 수 있어 문자열로 받아 직접 파싱
 */
@Slf4j
@Component
public class SeoulBikeClient implements StationSource {

    private final RestClient restClient;
    private final SeoulBikeProperties properties;
    private final JsonMapper jsonMapper;

    public SeoulBikeClient(
            @Qualifier("seoulBikeRestClient") RestClient restClient,
            SeoulBikeProperties properties,
            JsonMapper jsonMapper
    ) {
        this.restClient = restClient;
        this.properties = properties;
        this.jsonMapper = jsonMapper;
    }

    @Override
    public BikeOperator operator() {
        return BikeOperator.TTAREUNGYI;
    }

    @Override
    public boolean isEnabled() {
        return properties.hasApiKey();
    }

    @Override
    public List<Station> fetchAll() {
        if (!isEnabled()) {
            throw new StationFetchException("서울시 API 인증키가 없음");
        }
        int size = properties.pageSize();
        // 같은 ID가 두 페이지에 걸쳐 오면 먼저 온 것을 씀
        Map<String, Station> stations = new LinkedHashMap<>();
        int skipped = 0;

        for (int page = 0; page < properties.maxPages(); page++) {
            int start = page * size + 1;
            SeoulBikeResponse response = fetchPage(start, start + size - 1);
            String code = response.code();
            if (SeoulBikeResponse.NO_DATA.equals(code)) {
                return finish(stations, skipped);
            }
            if (!SeoulBikeResponse.OK.equals(code)) {
                throw new StationFetchException("서울시 API 오류 코드: " + code);
            }
            List<SeoulBikeResponse.Row> rows = response.rows();
            for (SeoulBikeResponse.Row row : rows) {
                Optional<Station> station = toStation(row);
                if (station.isPresent()) {
                    stations.putIfAbsent(station.get().id(), station.get());
                } else {
                    skipped++;
                }
            }
            if (rows.size() < size) {
                return finish(stations, skipped);
            }
        }
        // 끝까지 가득 찬 페이지만 왔다면 일부만 받은 것일 수 있으므로 쓰지 않음
        throw new StationFetchException("최대 페이지 수(" + properties.maxPages() + ")를 넘음");
    }

    private List<Station> finish(Map<String, Station> stations, int skipped) {
        if (skipped > 0) {
            log.warn("서울시 정류장 {}건은 값이 잘못되어 제외", skipped);
        }
        return new ArrayList<>(stations.values());
    }

    private SeoulBikeResponse fetchPage(int start, int end) {
        String body;
        try {
            body = restClient.get()
                    .uri("/{key}/json/bikeList/{start}/{end}/", properties.apiKey(), start, end)
                    .retrieve()
                    .body(String.class);
        } catch (RestClientResponseException e) {
            throw new StationFetchException("서울시 API HTTP " + e.getStatusCode().value());
        } catch (RestClientException e) {
            // 연결 실패 메시지에는 요청 URL(인증키 포함)이 들어 있어 예외 종류만 남김
            throw new StationFetchException("서울시 API 호출 실패: " + e.getClass().getSimpleName());
        }
        if (body == null || body.isBlank()) {
            throw new StationFetchException("서울시 API 응답 본문 없음");
        }
        try {
            return jsonMapper.readValue(body, SeoulBikeResponse.class);
        } catch (JacksonException e) {
            throw new StationFetchException("서울시 API 응답 형식 오류");
        }
    }

    /** 공통 모델로 변환. ID, 이름, 좌표가 잘못되면 제외 */
    static Optional<Station> toStation(SeoulBikeResponse.Row row) {
        String id = trim(row.stationId());
        String name = trim(row.stationName());
        Double latitude = parseDouble(row.stationLatitude());
        Double longitude = parseDouble(row.stationLongitude());
        if (id == null || name == null || latitude == null || longitude == null) {
            return Optional.empty();
        }
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 || (latitude == 0 && longitude == 0)) {
            return Optional.empty();
        }
        return Optional.of(new Station(id, name, BikeOperator.TTAREUNGYI, latitude, longitude, parseInt(row.rackTotCnt())));
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

    private static Integer parseInt(String value) {
        try {
            return value == null ? null : Integer.valueOf(value.strip());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}

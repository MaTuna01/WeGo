package com.tuna.wegobackend.station.seoul;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import com.tuna.wegobackend.station.BikeOperator;
import com.tuna.wegobackend.station.Station;
import com.tuna.wegobackend.station.StationFetchException;
import java.io.IOException;
import java.time.Duration;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.IntStream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;
import tools.jackson.databind.json.JsonMapper;

class SeoulBikeClientTest {

    private static final String KEY = "test-secret-key";
    private static final String BASE = "http://seoul.test";

    private MockRestServiceServer server;

    private SeoulBikeClient client(int pageSize, int maxPages, String apiKey) {
        RestClient.Builder builder = RestClient.builder().baseUrl(BASE);
        server = MockRestServiceServer.bindTo(builder).build();
        var properties = new SeoulBikeProperties(apiKey, BASE, pageSize, maxPages, Duration.ofSeconds(1), Duration.ofSeconds(1));
        return new SeoulBikeClient(builder.build(), properties, JsonMapper.builder().build());
    }

    private SeoulBikeClient client(int pageSize, int maxPages) {
        return client(pageSize, maxPages, KEY);
    }

    private static String url(int start, int end) {
        return BASE + "/" + KEY + "/json/bikeList/" + start + "/" + end + "/";
    }

    private static String row(String id, String name, String lat, String lon, String racks) {
        return """
                {"rackTotCnt":"%s","stationName":"%s","parkingBikeTotCnt":"3","shared":"20",\
                "stationLatitude":"%s","stationLongitude":"%s","stationId":"%s"}""".formatted(racks, name, lat, lon, id);
    }

    private static String page(List<String> rows) {
        return """
                {"rentBikeStatus":{"list_total_count":%d,"RESULT":{"CODE":"INFO-000","MESSAGE":"정상 처리되었습니다."},"row":[%s]}}"""
                .formatted(rows.size(), String.join(",", rows));
    }

    private static List<String> rows(int from, int count) {
        return IntStream.range(from, from + count)
                .mapToObj(i -> row("ST-" + i, i + ". 정류장 " + i, "37.5" + (i % 10), "126.9" + (i % 10), "10"))
                .collect(Collectors.toList());
    }

    private static final String NO_DATA = """
            {"RESULT":{"CODE":"INFO-200","MESSAGE":"해당하는 데이터가 없습니다."}}""";

    @Test
    @DisplayName("페이지를 나눠 받고, 마지막 페이지가 덜 차면 멈춘다")
    void fetchesPagesUntilShortPage() {
        var client = client(3, 10);
        server.expect(requestTo(url(1, 3))).andRespond(withSuccess(page(rows(1, 3)), MediaType.APPLICATION_JSON));
        server.expect(requestTo(url(4, 6))).andRespond(withSuccess(page(rows(4, 2)), MediaType.APPLICATION_JSON));

        List<Station> stations = client.fetchAll();

        assertThat(stations).extracting(Station::id).containsExactly("ST-1", "ST-2", "ST-3", "ST-4", "ST-5");
        server.verify();
    }

    @Test
    @DisplayName("딱 맞게 끝나면 다음 페이지의 데이터 없음(INFO-200)에서 멈춘다")
    void stopsOnNoData() {
        var client = client(2, 10);
        server.expect(requestTo(url(1, 2))).andRespond(withSuccess(page(rows(1, 2)), MediaType.APPLICATION_JSON));
        server.expect(requestTo(url(3, 4))).andRespond(withSuccess(NO_DATA, MediaType.APPLICATION_JSON));

        assertThat(client.fetchAll()).hasSize(2);
        server.verify();
    }

    @Test
    @DisplayName("응답 Content-Type이 JSON이 아니어도 읽는다")
    void readsNonJsonContentType() {
        var client = client(1000, 10);
        server.expect(requestTo(url(1, 1000))).andRespond(withSuccess(page(rows(1, 1)), MediaType.TEXT_PLAIN));

        assertThat(client.fetchAll()).hasSize(1);
    }

    @Test
    @DisplayName("공통 모델로 바꾸고 잔여 대수는 버린다")
    void convertsToCommonModel() {
        var client = client(1000, 10);
        String body = page(List.of(row("ST-4", " 102. 망원역 1번출구 앞 ", "37.55564880", "126.91062927", "15")));
        server.expect(requestTo(url(1, 1000))).andRespond(withSuccess(body, MediaType.APPLICATION_JSON));

        Station station = client.fetchAll().getFirst();

        assertThat(station).isEqualTo(new Station("ST-4", "102. 망원역 1번출구 앞", BikeOperator.TTAREUNGYI, 37.5556488, 126.91062927, 15));
    }

    @Test
    @DisplayName("ID, 이름, 좌표가 잘못된 정류장은 빼고 거치대 수를 모르면 null로 둔다")
    void skipsInvalidRows() {
        var client = client(1000, 10);
        String body = page(List.of(
                row("", "이름", "37.5", "126.9", "10"),
                row("ST-A", " ", "37.5", "126.9", "10"),
                row("ST-B", "좌표 없음", "", "126.9", "10"),
                row("ST-C", "좌표 0", "0", "0", "10"),
                row("ST-D", "위도 범위 밖", "91", "126.9", "10"),
                row("ST-E", "숫자 아님", "abc", "126.9", "10"),
                row("ST-OK", "정상", "37.5", "126.9", "")));
        server.expect(requestTo(url(1, 1000))).andRespond(withSuccess(body, MediaType.APPLICATION_JSON));

        List<Station> stations = client.fetchAll();

        assertThat(stations).extracting(Station::id).containsExactly("ST-OK");
        assertThat(stations.getFirst().dockCount()).isNull();
    }

    @Test
    @DisplayName("같은 ID가 두 번 오면 먼저 온 것을 쓴다")
    void deduplicatesById() {
        var client = client(2, 10);
        server.expect(requestTo(url(1, 2))).andRespond(withSuccess(
                page(List.of(row("ST-1", "첫 번째", "37.5", "126.9", "10"), row("ST-2", "둘", "37.5", "126.9", "10"))),
                MediaType.APPLICATION_JSON));
        server.expect(requestTo(url(3, 4))).andRespond(withSuccess(
                page(List.of(row("ST-1", "중복", "37.5", "126.9", "10"))), MediaType.APPLICATION_JSON));

        List<Station> stations = client.fetchAll();

        assertThat(stations).extracting(Station::name).containsExactly("첫 번째", "둘");
    }

    @Test
    @DisplayName("오류 코드가 오면 실패하고 일부만 돌려주지 않는다")
    void failsOnErrorCode() {
        var client = client(2, 10);
        server.expect(requestTo(url(1, 2))).andRespond(withSuccess(page(rows(1, 2)), MediaType.APPLICATION_JSON));
        server.expect(requestTo(url(3, 4))).andRespond(withSuccess(
                "{\"RESULT\":{\"CODE\":\"INFO-100\",\"MESSAGE\":\"인증키가 유효하지 않습니다.\"}}", MediaType.APPLICATION_JSON));

        assertThatThrownBy(client::fetchAll)
                .isInstanceOf(StationFetchException.class)
                .hasMessageContaining("INFO-100");
    }

    @Test
    @DisplayName("HTTP 오류, 연결 실패, 깨진 응답의 예외 메시지에 인증키를 남기지 않는다")
    void neverLeaksApiKey() {
        var serverError = client(1000, 10);
        server.expect(requestTo(url(1, 1000))).andRespond(withServerError());
        assertThatThrownBy(serverError::fetchAll)
                .isInstanceOf(StationFetchException.class)
                .hasMessageContaining("500")
                .hasMessageNotContaining(KEY)
                .hasNoCause();

        var offline = client(1000, 10);
        server.expect(requestTo(url(1, 1000))).andRespond(request -> {
            throw new IOException("Connection refused: " + request.getURI());
        });
        assertThatThrownBy(offline::fetchAll)
                .isInstanceOf(StationFetchException.class)
                .hasMessageNotContaining(KEY)
                .hasNoCause();

        var broken = client(1000, 10);
        server.expect(requestTo(url(1, 1000))).andRespond(withSuccess("<html>" + KEY + "</html>", MediaType.TEXT_HTML));
        assertThatThrownBy(broken::fetchAll)
                .isInstanceOf(StationFetchException.class)
                .hasMessageNotContaining(KEY)
                .hasNoCause();
    }

    @Test
    @DisplayName("최대 페이지 수까지 가득 찬 페이지만 오면 일부일 수 있으므로 실패한다")
    void failsWhenMaxPagesReached() {
        var client = client(1, 2);
        server.expect(requestTo(url(1, 1))).andRespond(withSuccess(page(rows(1, 1)), MediaType.APPLICATION_JSON));
        server.expect(requestTo(url(2, 2))).andRespond(withSuccess(page(rows(2, 1)), MediaType.APPLICATION_JSON));

        assertThatThrownBy(client::fetchAll).isInstanceOf(StationFetchException.class);
    }

    @Test
    @DisplayName("인증키가 없으면 꺼진 상태로 보고 호출하지 않는다")
    void disabledWithoutKey() {
        var client = client(1000, 10, " ");
        assertThat(client.isEnabled()).isFalse();
        assertThatThrownBy(client::fetchAll).isInstanceOf(StationFetchException.class);
        server.verify();
    }
}

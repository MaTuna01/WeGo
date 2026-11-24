package com.tuna.wegobackend.station.tashu;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.ExpectedCount.never;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import com.tuna.wegobackend.station.BikeOperator;
import com.tuna.wegobackend.station.Station;
import com.tuna.wegobackend.station.StationFetchException;
import java.io.IOException;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;
import tools.jackson.databind.json.JsonMapper;

class TashuClientTest {

    private static final String KEY = "test-secret-key";
    private static final String BASE = "https://tashu.test:50041";
    private static final String FIRST = BASE + TashuClient.STATIONS_PATH;

    private MockRestServiceServer server;

    private TashuClient client(int maxPages, String apiKey) {
        RestClient.Builder builder = RestClient.builder().baseUrl(BASE);
        server = MockRestServiceServer.bindTo(builder).build();
        var properties = new TashuProperties(apiKey, BASE, maxPages, Duration.ofSeconds(1), Duration.ofSeconds(1));
        return new TashuClient(builder.build(), properties, JsonMapper.builder().build());
    }

    private TashuClient client() {
        return client(10, KEY);
    }

    /** 실제 응답과 같은 모양(좌표는 문자열, x_pos가 위도) */
    private static String row(String id, String name, String xPos, String yPos) {
        return """
                {"id":"%s","name":"%s","name_en":"%s","name_cn":"%s / 10대용*1 / 10",\
                "x_pos":"%s","y_pos":"%s","address":"대전광역시 서구 탄방동 730","parking_count":3}"""
                .formatted(id, name, name, name, xPos, yPos);
    }

    private static String page(String next, String... rows) {
        String nextValue = next == null ? "null" : "\"" + next + "\"";
        return """
                {"count":%d,"next":%s,"previous":null,"results":[%s]}"""
                .formatted(rows.length, nextValue, String.join(",", rows));
    }

    private static final String NO_PERMISSION = """
            {"error_code":"1001","message":"권한이 없습니다.","message_en":"You do not have permission.",\
            "message_cn":"权限不存在。","status_code":400}""";

    @Test
    @DisplayName("api-token 헤더로 인증키를 보내고 한 페이지로 끝나면 바로 돌려준다")
    void fetchesSinglePage() {
        var client = client();
        server.expect(requestTo(FIRST))
                .andExpect(header(TashuClient.API_TOKEN_HEADER, KEY))
                .andRespond(withSuccess(page(null,
                        row("ST0003", "탄방동 한사랑병원", "36.348446", "127.390052"),
                        row("ST0004", "탄방동_한가람아파트(2동)", "36.348201", "127.390409")), MediaType.APPLICATION_JSON));

        List<Station> stations = client.fetchAll();

        assertThat(stations).extracting(Station::id).containsExactly("TS-ST0003", "TS-ST0004");
        server.verify();
    }

    @Test
    @DisplayName("x_pos를 위도, y_pos를 경도로 읽고 ID에 접두어를 붙이며 이름 공백을 지운다")
    void convertsToCommonModel() {
        var client = client();
        server.expect(requestTo(FIRST)).andRespond(withSuccess(
                page(null, row("ST0212", "상대동 도안 9단지 트리풀시티(920동)버스정류장 ", "36.341505", "127.338001")),
                MediaType.APPLICATION_JSON));

        Station station = client.fetchAll().getFirst();

        assertThat(station).isEqualTo(new Station(
                "TS-ST0212", "상대동 도안 9단지 트리풀시티(920동)버스정류장", BikeOperator.TASHU, 36.341505, 127.338001, null));
    }

    @Test
    @DisplayName("next가 있으면 같은 서버의 다음 페이지를 인증키와 함께 받는다")
    void followsNext() {
        var client = client();
        String second = BASE + TashuClient.STATIONS_PATH + "?page=2";
        server.expect(requestTo(FIRST)).andRespond(withSuccess(
                page(second, row("ST0001", "가", "36.35", "127.38")), MediaType.APPLICATION_JSON));
        server.expect(requestTo(second))
                .andExpect(header(TashuClient.API_TOKEN_HEADER, KEY))
                .andRespond(withSuccess(page(null, row("ST0002", "나", "36.35", "127.38")), MediaType.APPLICATION_JSON));

        assertThat(client.fetchAll()).extracting(Station::id).containsExactly("TS-ST0001", "TS-ST0002");
        server.verify();
    }

    @Test
    @DisplayName("next가 다른 서버를 가리키면 인증키를 보내지 않고 실패한다")
    void refusesNextOnOtherServer() {
        var client = client();
        String elsewhere = "https://evil.test/v1/openapi/station?page=2";
        server.expect(requestTo(FIRST)).andRespond(withSuccess(
                page(elsewhere, row("ST0001", "가", "36.35", "127.38")), MediaType.APPLICATION_JSON));
        server.expect(never(), requestTo(elsewhere));

        assertThatThrownBy(client::fetchAll)
                .isInstanceOf(StationFetchException.class)
                .hasMessageContaining("다른 서버");
        server.verify();
    }

    @Test
    @DisplayName("ID, 이름이 없거나 좌표가 대전 범위를 벗어나면(뒤바뀐 좌표 포함) 뺀다")
    void skipsInvalidRows() {
        var client = client();
        server.expect(requestTo(FIRST)).andRespond(withSuccess(page(null,
                row("", "ID 없음", "36.35", "127.38"),
                row("ST0010", " ", "36.35", "127.38"),
                row("ST0011", "좌표 없음", "", "127.38"),
                row("ST0012", "숫자 아님", "abc", "127.38"),
                row("ST0013", "위도, 경도 뒤바뀜", "127.38", "36.35"),
                row("ST0014", "서울 좌표", "37.55", "126.91"),
                row("ST0015", "좌표 0", "0", "0"),
                row("ST0016", "정상", "36.35", "127.38")), MediaType.APPLICATION_JSON));

        assertThat(client.fetchAll()).extracting(Station::id).containsExactly("TS-ST0016");
    }

    @Test
    @DisplayName("같은 ID가 두 번 오면 먼저 온 것을 쓴다")
    void deduplicatesById() {
        var client = client();
        server.expect(requestTo(FIRST)).andRespond(withSuccess(page(null,
                row("ST0001", "첫 번째", "36.35", "127.38"),
                row("ST0001", "중복", "36.35", "127.38")), MediaType.APPLICATION_JSON));

        assertThat(client.fetchAll()).extracting(Station::name).containsExactly("첫 번째");
    }

    @Test
    @DisplayName("권한 오류(HTTP 400, error_code)면 오류 코드를 남기고 실패한다")
    void failsOnPermissionError() {
        var client = client();
        server.expect(requestTo(FIRST)).andRespond(
                withStatus(HttpStatus.BAD_REQUEST).contentType(MediaType.APPLICATION_JSON).body(NO_PERMISSION));

        assertThatThrownBy(client::fetchAll)
                .isInstanceOf(StationFetchException.class)
                .hasMessageContaining("400")
                .hasMessageContaining("1001");
    }

    @Test
    @DisplayName("HTTP 200이어도 error_code가 오면 실패한다")
    void failsOnErrorCodeWithOk() {
        var client = client();
        server.expect(requestTo(FIRST)).andRespond(withSuccess(NO_PERMISSION, MediaType.APPLICATION_JSON));

        assertThatThrownBy(client::fetchAll)
                .isInstanceOf(StationFetchException.class)
                .hasMessageContaining("1001");
    }

    @Test
    @DisplayName("연결 실패, 깨진 응답의 예외 메시지에 인증키를 남기지 않는다")
    void neverLeaksApiKey() {
        var offline = client();
        server.expect(requestTo(FIRST)).andRespond(request -> {
            throw new IOException("Connection refused: " + request.getHeaders().getFirst(TashuClient.API_TOKEN_HEADER));
        });
        assertThatThrownBy(offline::fetchAll)
                .isInstanceOf(StationFetchException.class)
                .hasMessageNotContaining(KEY)
                .hasNoCause();

        var broken = client();
        server.expect(requestTo(FIRST)).andRespond(withSuccess("<html>" + KEY + "</html>", MediaType.TEXT_HTML));
        assertThatThrownBy(broken::fetchAll)
                .isInstanceOf(StationFetchException.class)
                .hasMessageNotContaining(KEY)
                .hasNoCause();
    }

    @Test
    @DisplayName("최대 페이지 수까지 next가 이어지면 일부일 수 있으므로 실패한다")
    void failsWhenMaxPagesReached() {
        var client = client(2, KEY);
        String second = FIRST + "?page=2";
        String third = FIRST + "?page=3";
        server.expect(requestTo(FIRST)).andRespond(withSuccess(
                page(second, row("ST0001", "가", "36.35", "127.38")), MediaType.APPLICATION_JSON));
        server.expect(requestTo(second)).andRespond(withSuccess(
                page(third, row("ST0002", "나", "36.35", "127.38")), MediaType.APPLICATION_JSON));

        assertThatThrownBy(client::fetchAll)
                .isInstanceOf(StationFetchException.class)
                .hasMessageContaining("최대 페이지");
    }

    @Test
    @DisplayName("인증키가 없으면 꺼진 상태로 보고 호출하지 않는다")
    void disabledWithoutKey() {
        var client = client(10, " ");
        assertThat(client.isEnabled()).isFalse();
        assertThatThrownBy(client::fetchAll).isInstanceOf(StationFetchException.class);
        server.verify();
    }
}

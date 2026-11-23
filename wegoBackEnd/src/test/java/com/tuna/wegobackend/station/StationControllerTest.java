package com.tuna.wegobackend.station;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.tuna.wegobackend.TestcontainersConfiguration;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class StationControllerTest {

    @Autowired
    MockMvc mockMvc;

    @Autowired
    StationRepository repository;

    @Autowired
    StationListService stationListService;

    @BeforeEach
    void reset() {
        repository.deleteAll();
    }

    /** DB에 두 곳을 넣고 그때의 ETag를 돌려줌 */
    private String loadStations() {
        repository.save(StationEntity.firstSeen(
                new Station("ST-5", "103. 망원역 2번출구 앞", BikeOperator.TTAREUNGYI, 37.5554, 126.9104, null), "ST-5", Instant.EPOCH));
        repository.save(StationEntity.firstSeen(
                new Station("ST-4", "102. 망원역 1번출구 앞", BikeOperator.TTAREUNGYI, 37.5556488, 126.91062927, 15), "ST-4", Instant.EPOCH));
        return stationListService.current().orElseThrow().etag();
    }

    @Test
    @DisplayName("아직 받지 못했으면 503 ProblemDetail과 Retry-After를 준다")
    void notReady() throws Exception {
        mockMvc.perform(get("/stations"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.status").value(503))
                .andExpect(header().string("Retry-After", "60"));
    }

    @Test
    @DisplayName("목록을 계약 모양으로 ETag와 함께 준다")
    void returnsStations() throws Exception {
        String etag = loadStations();

        mockMvc.perform(get("/stations").header("X-App-Version", "1.0.0"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(header().string("ETag", etag))
                .andExpect(header().string("Cache-Control", "no-cache"))
                .andExpect(jsonPath("$.stations.length()").value(2))
                .andExpect(jsonPath("$.stations[0].id").value("ST-4"))
                .andExpect(jsonPath("$.stations[0].name").value("102. 망원역 1번출구 앞"))
                .andExpect(jsonPath("$.stations[0].operator").value("ttareungyi"))
                .andExpect(jsonPath("$.stations[0].latitude").value(37.5556488))
                .andExpect(jsonPath("$.stations[0].longitude").value(126.91062927))
                .andExpect(jsonPath("$.stations[0].dockCount").value(15))
                .andExpect(jsonPath("$.stations[1].dockCount").isEmpty());
    }

    @Test
    @DisplayName("DB가 바뀌면 다음 요청부터 새 ETag와 본문을 준다")
    void reflectsDbChanges() throws Exception {
        String before = loadStations();
        repository.save(StationEntity.firstSeen(
                new Station("ST-6", "104. 망원역 3번출구 앞", BikeOperator.TTAREUNGYI, 37.5550, 126.9100, 10), "ST-6", Instant.EPOCH));

        mockMvc.perform(get("/stations").header("If-None-Match", before))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stations.length()").value(3));
    }

    @Test
    @DisplayName("If-None-Match가 지금 ETag와 같으면 본문 없이 304를 준다")
    void notModified() throws Exception {
        String etag = loadStations();

        var response = mockMvc.perform(get("/stations").header("If-None-Match", etag))
                .andExpect(status().isNotModified())
                .andExpect(header().string("ETag", etag))
                .andReturn().getResponse();

        assertThat(response.getContentAsByteArray()).isEmpty();
    }

    @Test
    @DisplayName("앱이 W/ 없이 보내도 같은 ETag로 본다")
    void notModifiedWithoutWeakPrefix() throws Exception {
        String etag = loadStations();

        mockMvc.perform(get("/stations").header("If-None-Match", etag.substring(2)))
                .andExpect(status().isNotModified());
    }

    @Test
    @DisplayName("ETag가 다르면 새 본문을 준다")
    void modified() throws Exception {
        loadStations();

        mockMvc.perform(get("/stations").header("If-None-Match", "\"old\""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stations.length()").value(2));
    }

    @Test
    @DisplayName("If-None-Match의 여러 값, W/ 유무, 와일드카드를 받는다")
    void matchesIfNoneMatchVariants() {
        String etag = "W/\"abc\"";
        assertThat(StationController.matches(etag, etag)).isTrue();
        assertThat(StationController.matches("\"abc\"", etag)).isTrue();
        assertThat(StationController.matches("\"x\", \"abc\"", etag)).isTrue();
        assertThat(StationController.matches("*", etag)).isTrue();
        assertThat(StationController.matches(null, etag)).isFalse();
        assertThat(StationController.matches("", etag)).isFalse();
        assertThat(StationController.matches("abc", etag)).isFalse();
        assertThat(StationController.matches("\"abcd\"", etag)).isFalse();
    }
}

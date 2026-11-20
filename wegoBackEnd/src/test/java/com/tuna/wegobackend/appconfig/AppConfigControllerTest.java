package com.tuna.wegobackend.appconfig;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

class AppConfigControllerTest {

    @Nested
    @SpringBootTest
    @AutoConfigureMockMvc
    @DisplayName("설정이 없을 때")
    class Default {

        @Autowired
        MockMvc mockMvc;

        @Test
        @DisplayName("최소 버전 1.0.0을 계약 모양 그대로 내려주고 캐시하지 않게 한다")
        void returnsDefault() throws Exception {
            mockMvc.perform(get("/app/config").header("X-App-Version", "1.0.0"))
                    .andExpect(status().isOk())
                    .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                    .andExpect(content().json("{\"minimumVersion\":\"1.0.0\"}", org.springframework.test.json.JsonCompareMode.STRICT))
                    .andExpect(header().string("Cache-Control", "no-store"));
        }

        @Test
        @DisplayName("앱 버전 헤더가 없어도 응답한다")
        void worksWithoutVersionHeader() throws Exception {
            mockMvc.perform(get("/app/config")).andExpect(status().isOk());
        }
    }

    @Nested
    @SpringBootTest(properties = "wego.app.minimum-version=1.2.0")
    @AutoConfigureMockMvc
    @DisplayName("설정값을 바꾸면")
    class Configured {

        @Autowired
        MockMvc mockMvc;

        @Test
        @DisplayName("그 값을 내려준다")
        void returnsConfigured() throws Exception {
            mockMvc.perform(get("/app/config"))
                    .andExpect(status().isOk())
                    .andExpect(content().json("{\"minimumVersion\":\"1.2.0\"}"));
        }
    }
}

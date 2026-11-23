package com.tuna.wegobackend.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.tuna.wegobackend.TestcontainersConfiguration;
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
class SecurityConfigTest {

    @Autowired
    MockMvc mockMvc;

    @Test
    @DisplayName("헬스 체크는 인증 없이 열려 있고 상세 정보는 보여주지 않는다")
    void healthIsPublic() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.components").doesNotExist());
    }

    @Test
    @DisplayName("앱이 쓰는 조회 경로는 보안에서 막지 않는다")
    void appPathsAreNotBlocked() throws Exception {
        for (String path : new String[] {"/app/config", "/stations"}) {
            int status = mockMvc.perform(get(path)).andReturn().getResponse().getStatus();
            assertThat(status).as(path).isNotEqualTo(403);
        }
    }

    @Test
    @DisplayName("공개 경로 외에는 모두 403 ProblemDetail로 막는다")
    void everythingElseIsForbidden() throws Exception {
        mockMvc.perform(get("/admin"))
                .andExpect(status().isForbidden())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.title").value("Forbidden"));

        // 공개 경로라도 GET이 아니면 막는다.
        mockMvc.perform(post("/stations")).andExpect(status().isForbidden());
        mockMvc.perform(delete("/app/config")).andExpect(status().isForbidden());

        // health 외의 actuator는 열지 않는다.
        mockMvc.perform(get("/actuator/env")).andExpect(status().isForbidden());
        mockMvc.perform(get("/actuator/info")).andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("세션을 만들지 않는다")
    void noSession() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(header().doesNotExist("Set-Cookie"));
    }
}

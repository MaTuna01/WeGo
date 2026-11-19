package com.tuna.wegobackend.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class AppVersionLoggingFilterTest {

    private final AppVersionLoggingFilter filter = new AppVersionLoggingFilter();

    @Test
    @DisplayName("버전 형식은 그대로 남긴다")
    void keepsVersion() {
        assertThat(AppVersionLoggingFilter.sanitize("1.0.0")).isEqualTo("1.0.0");
        assertThat(AppVersionLoggingFilter.sanitize(" 1.2.3 ")).isEqualTo("1.2.3");
        assertThat(AppVersionLoggingFilter.sanitize("1.0.0-beta+2")).isEqualTo("1.0.0-beta+2");
    }

    @Test
    @DisplayName("헤더가 없으면 none, 이상한 값은 원문 대신 invalid로 남긴다")
    void sanitizesOddValues() {
        assertThat(AppVersionLoggingFilter.sanitize(null)).isEqualTo("none");
        assertThat(AppVersionLoggingFilter.sanitize("  ")).isEqualTo("none");
        // 줄바꿈으로 가짜 로그 줄을 끼워 넣는 시도
        assertThat(AppVersionLoggingFilter.sanitize("1.0.0\nINFO admin login")).isEqualTo("invalid");
        assertThat(AppVersionLoggingFilter.sanitize("1.0.0 <script>")).isEqualTo("invalid");
        assertThat(AppVersionLoggingFilter.sanitize("1".repeat(21))).isEqualTo("invalid");
    }

    @Test
    @DisplayName("요청 처리 중에는 MDC에 버전이 있고, 끝나면 지운다")
    void putsAndClearsMdc() throws Exception {
        var request = new MockHttpServletRequest("GET", "/stations");
        request.addHeader(AppVersionLoggingFilter.HEADER, "1.0.0");
        var seen = new AtomicReference<String>();
        var chain = new MockFilterChain() {
            @Override
            public void doFilter(jakarta.servlet.ServletRequest req, jakarta.servlet.ServletResponse res) {
                seen.set(MDC.get(AppVersionLoggingFilter.MDC_KEY));
            }
        };

        filter.doFilter(request, new MockHttpServletResponse(), chain);

        assertThat(seen.get()).isEqualTo("1.0.0");
        assertThat(MDC.get(AppVersionLoggingFilter.MDC_KEY)).isNull();
    }

    @Test
    @DisplayName("처리 중 예외가 나도 MDC를 지운다")
    void clearsMdcOnError() {
        var request = new MockHttpServletRequest("GET", "/stations");
        request.addHeader(AppVersionLoggingFilter.HEADER, "1.0.0");
        var chain = new MockFilterChain() {
            @Override
            public void doFilter(jakarta.servlet.ServletRequest req, jakarta.servlet.ServletResponse res) {
                throw new IllegalStateException("boom");
            }
        };

        try {
            filter.doFilter(request, new MockHttpServletResponse(), chain);
        } catch (Exception ignored) {
            // 예외 전파 여부와 상관없이 MDC만 확인한다.
        }
        assertThat(MDC.get(AppVersionLoggingFilter.MDC_KEY)).isNull();
    }
}

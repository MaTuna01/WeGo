package com.tuna.wegobackend.common;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * 앱이 모든 요청에 보내는 X-App-Version을 로그에 남긴다(docs/api-contract.md).
 * 값은 MDC(appVersion)에 넣어 같은 요청의 모든 로그 줄에 찍히게 하고, 요청마다 한 줄 접근 로그를 남긴다.
 * 보안 필터보다 먼저 돌아서 막힌 요청도 기록한다.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class AppVersionLoggingFilter extends OncePerRequestFilter {

    public static final String HEADER = "X-App-Version";
    public static final String MDC_KEY = "appVersion";

    /** 헤더가 없을 때 */
    static final String MISSING = "none";
    /** 형식이 이상할 때(로그 주입 방지를 위해 원문을 남기지 않는다) */
    static final String INVALID = "invalid";

    private static final Pattern VERSION = Pattern.compile("[0-9A-Za-z.+-]{1,20}");
    private static final Logger log = LoggerFactory.getLogger(AppVersionLoggingFilter.class);

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        long startedAt = System.nanoTime();
        MDC.put(MDC_KEY, sanitize(request.getHeader(HEADER)));
        try {
            chain.doFilter(request, response);
        } finally {
            // 헬스 체크는 몇 초마다 들어오므로 접근 로그에서 뺀다.
            if (!request.getRequestURI().startsWith("/actuator/")) {
                long elapsedMs = (System.nanoTime() - startedAt) / 1_000_000;
                log.info("{} {} -> {} ({}ms)", request.getMethod(), request.getRequestURI(), response.getStatus(), elapsedMs);
            }
            // 스레드가 재사용되므로 다음 요청에 값이 남지 않게 지운다.
            MDC.remove(MDC_KEY);
        }
    }

    /** 버전 형식(숫자, 영문, 점, +, -, 20자 이내)만 그대로 남긴다. */
    static String sanitize(String header) {
        if (header == null || header.isBlank()) {
            return MISSING;
        }
        String value = header.strip();
        return VERSION.matcher(value).matches() ? value : INVALID;
    }
}

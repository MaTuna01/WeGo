package com.tuna.wegobackend.config;

import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

/**
 * 1.0 최소 서버 보안 설정. 로그인이 없으므로 앱이 쓰는 조회 API와 헬스 체크만 열고 나머지는 모두 막는다.
 * 1.1에서 로그인을 붙일 때 oauth2ResourceServer(JWT)를 여기에 추가한다.
 */
@Configuration
public class SecurityConfig {

    /** 인증 없이 열어 두는 경로(모두 GET) */
    static final String[] PUBLIC_GET_PATHS = {"/app/config", "/stations", "/actuator/health"};

    private static final String FORBIDDEN_BODY =
            "{\"type\":\"about:blank\",\"title\":\"Forbidden\",\"status\":403}";

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable)
                .requestCache(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.GET, PUBLIC_GET_PATHS).permitAll()
                        // 공개 경로에서 난 오류(404, 500 등)를 ProblemDetail로 그리는 내부 경로
                        .requestMatchers("/error").permitAll()
                        .anyRequest().denyAll())
                // 막힌 요청도 계약대로 ProblemDetail 형식으로 답한다(앱은 본문을 해석하지 않음).
                .exceptionHandling(exceptions -> exceptions
                        .authenticationEntryPoint((request, response, e) -> writeForbidden(response))
                        .accessDeniedHandler((request, response, e) -> writeForbidden(response)));
        return http.build();
    }

    private static void writeForbidden(HttpServletResponse response) throws IOException {
        response.setStatus(HttpServletResponse.SC_FORBIDDEN);
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        response.getWriter().write(FORBIDDEN_BODY);
    }
}

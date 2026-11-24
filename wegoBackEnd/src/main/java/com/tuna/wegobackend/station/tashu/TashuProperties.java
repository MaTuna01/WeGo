package com.tuna.wegobackend.station.tashu;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * 타슈 Open API 설정(wego.tashu.*)
 *
 * @param apiKey         인증키(api-token 헤더). 비우면 수집하지 않음(환경 변수로만 주입, 커밋 금지)
 * @param baseUrl        API 주소
 * @param maxPages       최대 페이지 수. next가 끝없이 이어지는 것을 막음
 * @param connectTimeout 연결 타임아웃
 * @param readTimeout    응답 타임아웃
 */
@Validated
@ConfigurationProperties(prefix = "wego.tashu")
public record TashuProperties(
        String apiKey,
        @NotBlank String baseUrl,
        @Min(1) int maxPages,
        @NotNull Duration connectTimeout,
        @NotNull Duration readTimeout
) {

    public boolean hasApiKey() {
        return apiKey != null && !apiKey.isBlank();
    }
}

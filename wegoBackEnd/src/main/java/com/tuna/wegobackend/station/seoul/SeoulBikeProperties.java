package com.tuna.wegobackend.station.seoul;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * 서울 열린데이터광장 공공자전거 API 설정(wego.seoul-bike.*)
 *
 * @param apiKey         인증키. 비우면 수집하지 않음(환경 변수로만 주입, 커밋 금지)
 * @param baseUrl        API 주소
 * @param pageSize       한 번에 받을 건수(API 최대 1,000)
 * @param maxPages       최대 페이지 수. 응답이 이상해서 끝없이 받는 것을 막음
 * @param connectTimeout 연결 타임아웃
 * @param readTimeout    응답 타임아웃
 */
@Validated
@ConfigurationProperties(prefix = "wego.seoul-bike")
public record SeoulBikeProperties(
        String apiKey,
        @NotBlank String baseUrl,
        @Min(1) @Max(1000) int pageSize,
        @Min(1) int maxPages,
        @NotNull Duration connectTimeout,
        @NotNull Duration readTimeout
) {

    public boolean hasApiKey() {
        return apiKey != null && !apiKey.isBlank();
    }
}

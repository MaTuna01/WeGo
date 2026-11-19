package com.tuna.wegobackend.appconfig;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * 앱 설정값(wego.app.*). 환경 변수로 바꾸고 서버 재시작으로 반영
 *
 * @param minimumVersion 최소 지원 앱 버전(major.minor.patch). 이보다 낮은 앱은 업데이트 안내로 막힘
 */
@Validated
@ConfigurationProperties(prefix = "wego.app")
public record AppConfigProperties(
        // 앱은 해석할 수 없는 값이면 막지 않으므로, 오타로 의도와 다르게 동작하지 않게 시작 시점에 거부
        @NotBlank @Pattern(regexp = "\\d+(\\.\\d+){0,2}", message = "major.minor.patch 숫자 형식이어야 함")
        String minimumVersion
) {
}

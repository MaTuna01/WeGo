package com.tuna.wegobackend.appconfig;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.autoconfigure.AutoConfigurations;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.boot.validation.autoconfigure.ValidationAutoConfiguration;
import org.springframework.context.annotation.Configuration;

class AppConfigPropertiesTest {

    @Configuration
    @EnableConfigurationProperties(AppConfigProperties.class)
    static class Config {
    }

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(ValidationAutoConfiguration.class))
            .withUserConfiguration(Config.class);

    @ParameterizedTest
    @ValueSource(strings = {"1.0.0", "1.2", "2", "10.20.30"})
    @DisplayName("숫자 버전 형식은 받는다")
    void acceptsVersion(String version) {
        runner.withPropertyValues("wego.app.minimum-version=" + version)
                .run(context -> assertThat(context.getBean(AppConfigProperties.class).minimumVersion()).isEqualTo(version));
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "latest", "1.0.0-beta", "v1.0", "1..0", "1.0.0.0"})
    @DisplayName("형식이 틀리면 서버가 시작하지 않는다")
    void rejectsInvalid(String version) {
        runner.withPropertyValues("wego.app.minimum-version=" + version)
                .run(context -> assertThat(context).hasFailed());
    }
}

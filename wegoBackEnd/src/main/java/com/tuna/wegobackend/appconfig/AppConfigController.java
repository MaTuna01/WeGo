package com.tuna.wegobackend.appconfig;

import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 앱 시작 시 읽는 설정. 지금은 최소 지원 버전만 내려줌
 */
@RestController
public class AppConfigController {

    private final AppConfigProperties properties;

    public AppConfigController(AppConfigProperties properties) {
        this.properties = properties;
    }

    @GetMapping("/app/config")
    public ResponseEntity<AppConfigResponse> config() {
        // 최소 버전을 올리면 바로 반영되도록 중간 캐시에 저장하지 않음
        return ResponseEntity.ok()
                .cacheControl(CacheControl.noStore())
                .body(new AppConfigResponse(properties.minimumVersion()));
    }
}

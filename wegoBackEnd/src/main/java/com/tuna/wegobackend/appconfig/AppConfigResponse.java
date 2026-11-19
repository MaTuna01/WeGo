package com.tuna.wegobackend.appconfig;

/**
 * GET /app/config 응답(docs/api-contract.md). 필드는 추가만 함
 */
public record AppConfigResponse(String minimumVersion) {
}

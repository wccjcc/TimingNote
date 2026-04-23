package com.timingnote.api.infra.security;

import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * 디바이스 시크릿 생성 및 해시 유틸리티
 */
@Component
public class DeviceSecretManager {

    private static final String HMAC_ALGORITHM = "HmacSHA256";
    private static final int SECRET_BYTE_LENGTH = 32;
    private final SecureRandom secureRandom = new SecureRandom();

    @Value("${security.device-secret.pepper}")
    private String pepper;

    // 클라이언트에게 1회 전달할 평문 시크릿 생성
    public String generateRawSecret() {
        byte[] randomBytes = new byte[SECRET_BYTE_LENGTH];
        secureRandom.nextBytes(randomBytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
    }

    // DB 저장/조회용 고정 해시 생성
    public String hash(String rawSecret) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGORITHM);
            mac.init(new SecretKeySpec(pepper.getBytes(StandardCharsets.UTF_8), HMAC_ALGORITHM));
            byte[] digest = mac.doFinal(rawSecret.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(digest);
        } catch (Exception ex) {
            throw new IllegalStateException("deviceSecret hash 생성에 실패했습니다.", ex);
        }
    }
}

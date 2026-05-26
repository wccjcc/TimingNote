package com.timingnote.api.infra.security;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class DeviceSecretManagerTest {

    private final DeviceSecretManager manager = new DeviceSecretManager("test-pepper");

    @Test
    void generateRawSecretReturnsUrlSafeBase64WithoutPadding() {
        // when
        String rawSecret = manager.generateRawSecret();

        // then
        assertThat(rawSecret)
                .hasSize(43)
                .doesNotContain("=")
                .matches("[A-Za-z0-9_-]+");
    }

    @Test
    void generateRawSecretReturnsDifferentValues() {
        // when
        String first = manager.generateRawSecret();
        String second = manager.generateRawSecret();

        // then
        assertThat(first).isNotEqualTo(second);
    }

    @Test
    void hashIsDeterministicForSameRawSecretAndPepper() {
        // when
        String first = manager.hash("raw-secret");
        String second = manager.hash("raw-secret");

        // then
        assertThat(first)
                .isEqualTo(second)
                .hasSize(43)
                .doesNotContain("=")
                .matches("[A-Za-z0-9_-]+");
    }

    @Test
    void hashChangesWhenPepperChanges() {
        // given
        DeviceSecretManager otherManager = new DeviceSecretManager("other-pepper");

        // when
        String hash = manager.hash("raw-secret");
        String otherHash = otherManager.hash("raw-secret");

        // then
        assertThat(hash).isNotEqualTo(otherHash);
    }
}

package com.timingnote.api.domain.user.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * SYS-01 디바이스 등록 요청 DTO
 */
@Getter
@NoArgsConstructor
public class UserRegisterRequestDto {

    @Schema(
            description = "앱 설치 단위 고유 UUID",
            example = "550e8400-e29b-41d4-a716-446655440000"
    )
    @NotBlank(message = "installationUuid는 필수입니다.")
    @Pattern(
            regexp = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$",
            message = "installationUuid는 UUID 형식이어야 합니다."
    )
    private String installationUuid;
}
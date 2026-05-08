package com.timingnote.api.domain.image.controller;

import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.image.dto.request.ImageUploadUrlRequestDto;
import com.timingnote.api.domain.image.dto.response.ImageUploadUrlResponseDto;
import com.timingnote.api.domain.image.service.ImageService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 이미지 업로드 API 컨트롤러
 */
@Tag(name = "Image", description = "이미지 업로드 API")
@RestController
@RequestMapping("/api/v1/images")
@RequiredArgsConstructor
public class ImageController {

    private final ImageService imageService;

    @Operation(
            summary = "Presigned URL 발급",
            description = "클라이언트가 S3에 직접 업로드할 수 있는 Presigned PUT URL을 발급한다."
    )
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "발급 성공"),
            @ApiResponse(responseCode = "400", description = "요청 값 검증 실패",
                    content = @Content(schema = @Schema(implementation = ApiResponseDto.class)))
    })
    @PostMapping("/upload-url")
    public ApiResponseDto<ImageUploadUrlResponseDto> createUploadUrl(
            @Valid @RequestBody ImageUploadUrlRequestDto request) {
        return ApiResponseDto.success(imageService.createUploadUrl(request));
    }
}


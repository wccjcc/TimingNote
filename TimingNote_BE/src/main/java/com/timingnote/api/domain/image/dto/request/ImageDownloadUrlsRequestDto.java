package com.timingnote.api.domain.image.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@Schema(description = "이미지 Presigned GET URL 발급 요청")
public class ImageDownloadUrlsRequestDto {

    @NotEmpty
    @Schema(description = "다운로드 URL이 필요한 S3 objectKey 목록")
    private List<String> objectKeys;
}


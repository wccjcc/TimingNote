package com.timingnote.api.domain.user.controller;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.common.response.ApiResponseDto;
import com.timingnote.api.domain.user.dto.request.UserPlaceCreateRequest;
import com.timingnote.api.domain.user.dto.request.UserPlaceUpdateRequest;
import com.timingnote.api.domain.user.dto.response.UserPlaceResponse;
import com.timingnote.api.domain.user.service.UserPlaceService;
import com.timingnote.api.infra.security.DeviceSecretAuthInterceptor;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "내 장소", description = "사용자 등록 장소(별칭) CRUD API")
@RestController
@RequestMapping("/api/v1/user-places")
@RequiredArgsConstructor
public class UserPlaceController {

    private final UserPlaceService userPlaceService;

    @Operation(summary = "내 장소 목록 조회", description = "사용자가 등록한 모든 내 장소를 반환합니다.")
    @ApiResponse(responseCode = "200", description = "조회 성공")
    @GetMapping
    public ApiResponseDto<List<UserPlaceResponse>> getUserPlaces(HttpServletRequest request) {
        Long userId = extractUserId(request);
        return ApiResponseDto.success(userPlaceService.getUserPlaces(userId));
    }

    @Operation(summary = "내 장소 등록", description = "Kakao 검색 결과 또는 지도 마커 핀으로 장소를 등록합니다.")
    @ApiResponse(responseCode = "200", description = "등록 성공")
    @ApiResponse(responseCode = "400", description = "입력값 오류")
    @PostMapping
    public ApiResponseDto<UserPlaceResponse> createUserPlace(
            @Valid @RequestBody UserPlaceCreateRequest request,
            HttpServletRequest httpRequest) {
        Long userId = extractUserId(httpRequest);
        return ApiResponseDto.success(userPlaceService.createUserPlace(userId, request));
    }

    @Operation(summary = "내 장소 별칭 수정", description = "등록된 장소의 별칭을 변경합니다.")
    @ApiResponse(responseCode = "200", description = "수정 성공")
    @ApiResponse(responseCode = "404", description = "장소를 찾을 수 없음")
    @PatchMapping("/{userPlaceId}")
    public ApiResponseDto<UserPlaceResponse> updateUserPlace(
            @Parameter(description = "내 장소 ID") @PathVariable Long userPlaceId,
            @Valid @RequestBody UserPlaceUpdateRequest request,
            HttpServletRequest httpRequest) {
        Long userId = extractUserId(httpRequest);
        return ApiResponseDto.success(userPlaceService.updateUserPlace(userId, userPlaceId, request));
    }

    @Operation(summary = "내 장소 삭제", description = "등록된 장소를 삭제합니다.")
    @ApiResponse(responseCode = "200", description = "삭제 성공")
    @ApiResponse(responseCode = "404", description = "장소를 찾을 수 없음")
    @DeleteMapping("/{userPlaceId}")
    public ApiResponseDto<Void> deleteUserPlace(
            @Parameter(description = "내 장소 ID") @PathVariable Long userPlaceId,
            HttpServletRequest httpRequest) {
        Long userId = extractUserId(httpRequest);
        userPlaceService.deleteUserPlace(userId, userPlaceId);
        return ApiResponseDto.successMsg("삭제되었습니다.");
    }

    private Long extractUserId(HttpServletRequest request) {
        Object attr = request.getAttribute(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID);
        if (attr == null) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
        return (Long) attr;
    }
}

package com.timingnote.api.domain.user.service;

import com.timingnote.api.domain.user.dto.request.UserPlaceCreateRequest;
import com.timingnote.api.domain.user.dto.request.UserPlaceUpdateRequest;
import com.timingnote.api.domain.user.dto.response.UserPlaceResponse;
import java.util.List;

public interface UserPlaceService {

    /** 내 장소 목록 조회 */
    List<UserPlaceResponse> getUserPlaces(Long userId);

    /** 내 장소 등록 */
    UserPlaceResponse createUserPlace(Long userId, UserPlaceCreateRequest request);

    /** 내 장소 별칭 수정 */
    UserPlaceResponse updateUserPlace(Long userId, Long userPlaceId, UserPlaceUpdateRequest request);

    /** 내 장소 삭제 */
    void deleteUserPlace(Long userId, Long userPlaceId);
}

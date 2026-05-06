package com.timingnote.api.domain.user.service;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.place.dto.command.PlaceUpsertCommand;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.service.PlaceService;
import com.timingnote.api.domain.user.dto.request.UserPlaceCreateRequest;
import com.timingnote.api.domain.user.dto.request.UserPlaceUpdateRequest;
import com.timingnote.api.domain.user.dto.response.UserPlaceResponse;
import com.timingnote.api.domain.user.entity.UserPlace;
import com.timingnote.api.domain.user.repository.UserPlaceRepository;
import com.timingnote.api.domain.user.repository.UserRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserPlaceServiceImpl implements UserPlaceService {

    private final UserPlaceRepository userPlaceRepository;
    private final UserRepository userRepository;
    private final PlaceService placeService;

    @Override
    @Transactional(readOnly = true)
    public List<UserPlaceResponse> getUserPlaces(Long userId) {
        return userPlaceRepository.findWithPlaceByUserId(userId).stream()
                .map(UserPlaceResponse::from)
                .toList();
    }

    @Override
    @Transactional
    public UserPlaceResponse createUserPlace(Long userId, UserPlaceCreateRequest req) {
        // 장소 저장 또는 기존 장소 조회 (Kakao 검색 결과 or 지도 마커 핀)
        Place place = placeService.saveUserSelectedPlace(PlaceUpsertCommand.of(
                req.getKakaoPlaceId(), req.getPlaceName(),
                req.getAddressName(), req.getRoadAddressName(),
                req.getCategoryGroupCode(), req.getCategoryGroupName(),
                req.getPhone(), req.getPlaceUrl(),
                req.getLongitude(), req.getLatitude()));

        UserPlace userPlace = UserPlace.builder()
                .user(userRepository.getReferenceById(userId))
                .place(place)
                .aliasName(req.getAliasName())
                .build();

        UserPlace saved = userPlaceRepository.save(userPlace);
        log.info("[UserPlace] 등록: userId={} userPlaceId={} placeId={} alias='{}'",
                userId, saved.getId(), place.getId(), req.getAliasName());

        // 저장된 엔티티에서 응답 생성 (place는 이미 로드됨)
        return UserPlaceResponse.from(saved);
    }

    @Override
    @Transactional
    public UserPlaceResponse updateUserPlace(Long userId, Long userPlaceId, UserPlaceUpdateRequest req) {
        UserPlace userPlace = userPlaceRepository.findByIdAndUser_Id(userPlaceId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));

        userPlace.updateAliasName(req.getAliasName());
        log.info("[UserPlace] 별칭 수정: userPlaceId={} alias='{}'", userPlaceId, req.getAliasName());

        return UserPlaceResponse.from(userPlace);
    }

    @Override
    @Transactional
    public void deleteUserPlace(Long userId, Long userPlaceId) {
        UserPlace userPlace = userPlaceRepository.findByIdAndUser_Id(userPlaceId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));

        userPlaceRepository.delete(userPlace);
        log.info("[UserPlace] 삭제: userId={} userPlaceId={}", userId, userPlaceId);
    }
}

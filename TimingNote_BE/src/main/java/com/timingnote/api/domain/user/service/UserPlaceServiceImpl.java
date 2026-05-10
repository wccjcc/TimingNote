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

    /**
     * 사용자당 등록 가능한 내 장소(ALIAS) 최대 개수.
     * AI 프롬프트에 별칭 목록을 매번 주입하므로 토큰/매칭 정확도 측면에서 상한 필요.
     * FE의 추가 버튼 disable 기준과 동일하게 유지해야 함.
     */
    private static final int MAX_USER_PLACES_PER_USER = 10;

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
        // 한도/중복 사전 검증. 동시성 race 시 DB UNIQUE(user_id, alias_name) 제약이 안전망.
        if (userPlaceRepository.countByUser_Id(userId) >= MAX_USER_PLACES_PER_USER) {
            throw new BusinessException(
                    String.format("내 장소는 최대 %d개까지 등록할 수 있어요", MAX_USER_PLACES_PER_USER),
                    ErrorCode.USER_PLACE_LIMIT_EXCEEDED);
        }
        if (userPlaceRepository.existsByUser_IdAndAliasName(userId, req.getAliasName())) {
            throw new BusinessException(ErrorCode.USER_PLACE_NAME_DUPLICATED);
        }

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
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_PLACE_NOT_FOUND));

        // 같은 별칭으로의 no-op 수정은 통과시키되, 다른 user_place와 충돌하면 차단
        if (!userPlace.getAliasName().equals(req.getAliasName())
                && userPlaceRepository.existsByUser_IdAndAliasNameAndIdNot(
                        userId, req.getAliasName(), userPlaceId)) {
            throw new BusinessException(ErrorCode.USER_PLACE_NAME_DUPLICATED);
        }

        userPlace.updateAliasName(req.getAliasName());
        log.info("[UserPlace] 별칭 수정: userPlaceId={} alias='{}'", userPlaceId, req.getAliasName());

        return UserPlaceResponse.from(userPlace);
    }

    @Override
    @Transactional
    public void deleteUserPlace(Long userId, Long userPlaceId) {
        UserPlace userPlace = userPlaceRepository.findByIdAndUser_Id(userPlaceId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_PLACE_NOT_FOUND));

        userPlaceRepository.delete(userPlace);
        log.info("[UserPlace] 삭제: userId={} userPlaceId={}", userId, userPlaceId);
    }
}

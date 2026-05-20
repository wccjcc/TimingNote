package com.timingnote.api.domain.place.repository;

import com.timingnote.api.domain.place.entity.Place;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PlaceRepository extends JpaRepository<Place, Long> {

    Optional<Place> findByExternalPlaceId(String externalPlaceId);

    List<Place> findAllByExternalPlaceIdIn(List<String> externalPlaceIds);

    /**
     * 지도 핀(externalPlaceId == null) 케이스의 주소 기반 dedup.
     * <p>도로명 주소가 정확 일치하는 핀이 이미 있으면 그걸 재사용한다. roadAddress는 도로명+건물번호가
     * 결합돼 있어 동일 좌표·동일 표기일 때 충돌 위험이 매우 낮다. null roadAddress는 dedup 대상 아님
     * (호출자가 분기 전에 차단).
     */
    Optional<Place> findFirstByExternalPlaceIdIsNullAndRoadAddress(String roadAddress);

    /**
     * 지도 핀 dedup의 fallback — roadAddress 없을 때 지번 주소로 매칭.
     */
    Optional<Place> findFirstByExternalPlaceIdIsNullAndAddress(String address);
}

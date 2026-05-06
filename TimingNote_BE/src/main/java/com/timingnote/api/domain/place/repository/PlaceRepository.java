package com.timingnote.api.domain.place.repository;

import com.timingnote.api.domain.place.entity.Place;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PlaceRepository extends JpaRepository<Place, Long> {

    Optional<Place> findByExternalPlaceId(String externalPlaceId);

    List<Place> findAllByExternalPlaceIdIn(List<String> externalPlaceIds);
}

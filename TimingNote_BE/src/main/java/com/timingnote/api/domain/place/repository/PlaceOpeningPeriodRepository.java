package com.timingnote.api.domain.place.repository;

import com.timingnote.api.domain.place.entity.PlaceOpeningPeriod;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.util.List;

public interface PlaceOpeningPeriodRepository extends JpaRepository<PlaceOpeningPeriod, Long> {

    List<PlaceOpeningPeriod> findAllByPlaceId(Long placeId);

    @Modifying
    @Query("DELETE FROM PlaceOpeningPeriod p WHERE p.placeId = :placeId")
    void deleteAllByPlaceId(Long placeId);
}

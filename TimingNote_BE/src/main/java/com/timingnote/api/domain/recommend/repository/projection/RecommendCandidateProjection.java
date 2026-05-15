package com.timingnote.api.domain.recommend.repository.projection;

public interface RecommendCandidateProjection {

    Long getTodoId();

    String getSummaryText();

    String getCategory();

    String getResolvedPlaceLabel();

    Long getPlaceId();

    String getPlaceName();

    Double getLatitude();

    Double getLongitude();

    Integer getDistanceM();
}

package com.timingnote.api.domain.place.service;

import com.timingnote.api.domain.place.dto.response.PlaceSearchItemResponse;
import com.timingnote.api.infra.client.ai.AiPlaceType;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class PlaceTypeResolverTest {

    private final PlaceTypeResolver resolver = new PlaceTypeResolver();

    @Test
    void resolve_returnsMemo_whenSearchResultIsEmpty() {
        PlaceTypeResolver.Result result = resolver.resolve("롯데마트 수완점", List.of());

        assertThat(result.placeType()).isNull();
        assertThat(result.items()).isEmpty();
    }

    @Test
    void resolve_keepsGenericKeywordAsGeneric_evenWhenThereIsSingleExactCandidate() {
        PlaceTypeResolver.Result result = resolver.resolve("약국", List.of(place("1", "약국")));

        assertThat(result.placeType()).isEqualTo(AiPlaceType.GENERIC);
        assertThat(result.items()).hasSize(1);
    }

    @Test
    void resolve_returnsSpecific_whenNormalizedNameExactlyMatchesCandidateName() {
        List<PlaceSearchItemResponse> items = List.of(
                place("1", "분식집 롯데마트 수완점"),
                place("2", "롯데마트수완점")
        );

        PlaceTypeResolver.Result result = resolver.resolve("롯데마트 수완점", items);

        assertThat(result.placeType()).isEqualTo(AiPlaceType.SPECIFIC);
        assertThat(result.items())
                .hasSize(1)
                .first()
                .extracting(PlaceSearchItemResponse::getId)
                .isEqualTo("2");
    }

    @Test
    void resolve_returnsGeneric_whenOnlyRelatedCandidateContainsPlaceText() {
        List<PlaceSearchItemResponse> items = List.of(
                place("1", "광주수완도서관 주차장"),
                place("2", "광주수완도서관 공원")
        );

        PlaceTypeResolver.Result result = resolver.resolve("광주수완도서관", items);

        assertThat(result.placeType()).isEqualTo(AiPlaceType.GENERIC);
        assertThat(result.items()).hasSize(2);
    }

    @Test
    void resolve_returnsGeneric_whenBranchSuffixOrRegionWordWouldRequireRelaxedMatching() {
        PlaceTypeResolver.Result result = resolver.resolve(
                "롯데마트 수완",
                List.of(place("1", "롯데마트 광주 수완점"))
        );

        assertThat(result.placeType()).isEqualTo(AiPlaceType.GENERIC);
        assertThat(result.items()).hasSize(1);
    }

    @Test
    void resolve_returnsSpecific_whenOnlyBranchSuffixDiffers() {
        PlaceTypeResolver.Result result = resolver.resolve(
                "롯데마트 수완",
                List.of(place("1", "롯데마트 수완점"))
        );

        assertThat(result.placeType()).isEqualTo(AiPlaceType.SPECIFIC);
        assertThat(result.items())
                .hasSize(1)
                .first()
                .extracting(PlaceSearchItemResponse::getId)
                .isEqualTo("1");
    }

    @Test
    void resolve_keepsStoreNounSuffix_whenNameEndsWithBookstoreOrKiosk() {
        PlaceTypeResolver.Result result = resolver.resolve(
                "교보문고",
                List.of(place("1", "교보문고 서점"))
        );

        assertThat(result.placeType()).isEqualTo(AiPlaceType.GENERIC);
        assertThat(result.items()).hasSize(1);
    }

    private PlaceSearchItemResponse place(String id, String placeName) {
        return PlaceSearchItemResponse.builder()
                .id(id)
                .placeName(placeName)
                .build();
    }
}

package com.timingnote.api.domain.place.service.matching;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class PlaceNameSimilarityTest {

    @Test
    void similarityIgnoresWhitespacePunctuationAndStoreSuffix() {
        // when
        double similarity = PlaceNameSimilarity.similarity("스타벅스 서면점", "스타벅스-서면");

        // then
        assertThat(similarity).isEqualTo(1.0);
    }

    @Test
    void similarityRemovesLongStoreSuffixBeforeGenericBranchSuffix() {
        // when
        double similarity = PlaceNameSimilarity.similarity("교보문고 본점", "교보문고");

        // then
        assertThat(similarity).isEqualTo(1.0);
    }

    @Test
    void similarityRemovesNumberedBranchSuffix() {
        // when
        double similarity = PlaceNameSimilarity.similarity("스타벅스 2호점", "스타벅스");

        // then
        assertThat(similarity).isEqualTo(1.0);
    }

    @Test
    void similarityReturnsZeroForNullOrEmptyNames() {
        assertThat(PlaceNameSimilarity.similarity(null, "스타벅스")).isZero();
        assertThat(PlaceNameSimilarity.similarity("###", "스타벅스")).isZero();
    }

    @Test
    void isMatchUsesGivenMinimumSimilarity() {
        assertThat(PlaceNameSimilarity.isMatch("이마트 서면", "스타벅스 서면점", 0.4)).isFalse();
        assertThat(PlaceNameSimilarity.isMatch("스타벅스 서면점", "스타벅스 부산서면점", 0.4)).isTrue();
    }
}

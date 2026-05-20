package com.timingnote.api.domain.user.service;

import com.timingnote.api.domain.user.entity.UserPlace;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class UserPlaceAliasMatcherTest {

    private final UserPlaceAliasMatcher matcher = new UserPlaceAliasMatcher();

    @Test
    void findBestMatch_matchesAliasWithLocationParticle() {
        Optional<UserPlace> result = matcher.findBestMatch(
                "싸피집에서 치킨 먹기",
                List.of(userPlace(1L, "싸피집"))
        );

        assertThat(result).isPresent();
        assertThat(result.get().getAliasName()).isEqualTo("싸피집");
    }

    @Test
    void findBestMatch_matchesAliasAfterRemovingWhitespace() {
        Optional<UserPlace> result = matcher.findBestMatch(
                "우리 집에서 커피 마시기",
                List.of(userPlace(1L, "우리집"))
        );

        assertThat(result).isPresent();
        assertThat(result.get().getAliasName()).isEqualTo("우리집");
    }

    @Test
    void findBestMatch_matchesAliasSeparatedByWhitespace() {
        Optional<UserPlace> result = matcher.findBestMatch(
                "싸피집 치킨 먹기",
                List.of(userPlace(1L, "싸피집"))
        );

        assertThat(result).isPresent();
        assertThat(result.get().getAliasName()).isEqualTo("싸피집");
    }

    @Test
    void findBestMatch_prefersLongestAlias() {
        Optional<UserPlace> result = matcher.findBestMatch(
                "싸피집에서 치킨 먹기",
                List.of(
                        userPlace(1L, "집"),
                        userPlace(2L, "싸피집")
                )
        );

        assertThat(result).isPresent();
        assertThat(result.get().getId()).isEqualTo(2L);
    }

    @Test
    void findBestMatch_doesNotMatchAliasInsideAnotherPlaceName() {
        Optional<UserPlace> result = matcher.findBestMatch(
                "치킨집에서 먹기",
                List.of(userPlace(1L, "집"))
        );

        assertThat(result).isEmpty();
    }

    @Test
    void findBestMatch_doesNotMatchCompoundWithoutBoundary() {
        Optional<UserPlace> result = matcher.findBestMatch(
                "회사밥 먹기",
                List.of(userPlace(1L, "회사"))
        );

        assertThat(result).isEmpty();
    }

    private UserPlace userPlace(Long id, String aliasName) {
        return UserPlace.builder()
                .id(id)
                .aliasName(aliasName)
                .build();
    }
}

package com.timingnote.api.domain.user.service;

import com.timingnote.api.domain.user.entity.UserPlace;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

@Component
public class UserPlaceAliasMatcher {

    private static final List<String> LOCATION_SUFFIXES = List.of(
            "에서",
            "으로",
            "까지",
            "부터",
            "근처",
            "주변",
            "앞",
            "뒤",
            "옆",
            "안",
            "밖"
    );

    private static final List<String> SINGLE_PARTICLE_SUFFIXES = List.of("에", "로");

    public Optional<UserPlace> findBestMatch(String text, List<UserPlace> userPlaces) {
        if (!StringUtils.hasText(text) || userPlaces == null || userPlaces.isEmpty()) {
            return Optional.empty();
        }

        return userPlaces.stream()
                .filter(up -> StringUtils.hasText(up.getAliasName()))
                .sorted(Comparator
                        .comparingInt((UserPlace up) -> compactLength(up.getAliasName()))
                        .reversed()
                        .thenComparing(up -> up.getId() == null ? Long.MAX_VALUE : up.getId()))
                .filter(up -> containsAlias(text, up.getAliasName()))
                .findFirst();
    }

    private boolean containsAlias(String text, String alias) {
        for (int start = 0; start < text.length(); start++) {
            if (Character.isWhitespace(text.charAt(start))) {
                continue;
            }
            if (!hasPrefixBoundary(text, start)) {
                continue;
            }

            int end = matchAlias(text, start, alias);
            if (end >= 0 && hasSuffixBoundary(text, end)) {
                return true;
            }
        }
        return false;
    }

    private int matchAlias(String text, int start, String alias) {
        int textIndex = start;
        int aliasIndex = 0;

        while (aliasIndex < alias.length()) {
            while (textIndex < text.length() && Character.isWhitespace(text.charAt(textIndex))) {
                textIndex++;
            }
            while (aliasIndex < alias.length() && Character.isWhitespace(alias.charAt(aliasIndex))) {
                aliasIndex++;
            }
            if (aliasIndex >= alias.length()) {
                break;
            }
            if (textIndex >= text.length()) {
                return -1;
            }

            char textChar = Character.toLowerCase(text.charAt(textIndex));
            char aliasChar = Character.toLowerCase(alias.charAt(aliasIndex));
            if (textChar != aliasChar) {
                return -1;
            }
            textIndex++;
            aliasIndex++;
        }

        return aliasIndex >= alias.length() ? textIndex : -1;
    }

    private boolean hasPrefixBoundary(String text, int start) {
        if (start == 0) {
            return true;
        }
        return !Character.isLetterOrDigit(text.charAt(start - 1));
    }

    private boolean hasSuffixBoundary(String text, int index) {
        if (index >= text.length()) {
            return true;
        }
        char next = text.charAt(index);
        if (!Character.isLetterOrDigit(next)) {
            return true;
        }
        if (startsWithAny(text, index, LOCATION_SUFFIXES)) {
            return true;
        }
        return SINGLE_PARTICLE_SUFFIXES.stream()
                .anyMatch(suffix -> startsWithParticleAndBoundary(text, index, suffix));
    }

    private boolean startsWithAny(String text, int index, List<String> suffixes) {
        return suffixes.stream().anyMatch(suffix -> text.startsWith(suffix, index));
    }

    private boolean startsWithParticleAndBoundary(String text, int index, String suffix) {
        if (!text.startsWith(suffix, index)) {
            return false;
        }
        int afterSuffix = index + suffix.length();
        return afterSuffix >= text.length()
                || !Character.isLetterOrDigit(text.charAt(afterSuffix));
    }

    private int compactLength(String value) {
        int count = 0;
        for (int i = 0; i < value.length(); i++) {
            if (!Character.isWhitespace(value.charAt(i))) {
                count++;
            }
        }
        return count;
    }
}

package com.timingnote.api.domain.todo.service;

import com.timingnote.api.infra.client.ai.AiPlaceType;
import com.timingnote.api.infra.client.kakao.KakaoPlaceSearchStrategy;
import java.util.regex.Pattern;
import lombok.extern.slf4j.Slf4j;

/**
 * AI가 분류한 placeType을 BE에서 보수적으로 검증/보정한다.
 *
 * <p><b>문제 배경:</b> AI가 단일 브랜드명("스타벅스", "다이소")을 SPECIFIC으로 분류하는
 * 케이스가 빈번하다. 사용자 의도는 "가까운 어떤 지점이든"(GENERIC)인데 SPECIFIC로
 * 처리되면 카카오에서 잘못된 1순위 지점 1개에 고정되어 매칭 정확도가 떨어진다.
 *
 * <p><b>다운그레이드 룰 (SPECIFIC → GENERIC):</b> 다음 두 조건을 <b>모두</b> 만족할 때만 적용.
 * <ol>
 *   <li>{@link KakaoPlaceSearchStrategy#KEYWORD_TO_CODE 명시적 체인 키워드 매핑}에 해당
 *       (스타벅스, 다이소, 이마트, GS25, 맥도날드 등 화이트리스트)</li>
 *   <li>placeText 끝에 지점/위치 한정자가 없음 (예: "X점", "X지점", "X역", "X동")</li>
 * </ol>
 *
 * <p><b>왜 보수적인가:</b> 명시적 화이트리스트에 없는 동네 단일 매장
 * (예: "엽기떡볶이", "한양식당", "노가리집")은 동일 이름 점포가 1개뿐일 가능성이 높아
 * AI의 SPECIFIC 판단이 정확할 수 있다. 잘못된 다운그레이드(false positive)를 0에 가깝게
 * 유지하기 위해 화이트리스트 + 한정자 부재 두 조건 동시 만족만 다운그레이드한다.
 *
 * <p>운영 데이터 누적 후 KEYWORD_TO_CODE에 추가 체인을 등록하는 방식으로 점진 확장.
 */
@Slf4j
public final class AiPlaceTypeValidator {

    private AiPlaceTypeValidator() {}

    /** 지점/위치 한정자 — placeText 끝부분에 있으면 SPECIFIC 의도 명확. */
    private static final Pattern LOCATION_QUALIFIER = Pattern.compile(
            ".+(점|지점|본점|역|동|구|시|로|길|학교|병원|공항|터미널)\\s*$");

    /**
     * AI가 내려준 placeType을 검증해 필요 시 보정한다.
     *
     * @return 보정된 placeType (대부분의 경우 입력 그대로)
     */
    public static AiPlaceType validate(AiPlaceType aiType, String placeText) {
        if (aiType != AiPlaceType.SPECIFIC) return aiType;
        if (placeText == null || placeText.isBlank()) return aiType;

        // 조건 1: 명시적 체인 화이트리스트
        boolean isMappedChain = KakaoPlaceSearchStrategy.decide(placeText).useCategory();
        if (!isMappedChain) return aiType;

        // 조건 2: 지점/위치 한정자 부재
        boolean hasQualifier = LOCATION_QUALIFIER.matcher(placeText.trim()).matches();
        if (hasQualifier) return aiType;

        log.info("[AI/Validate] SPECIFIC → GENERIC 다운그레이드: '{}' (체인 화이트리스트 + 지점명 부재)",
                placeText);
        return AiPlaceType.GENERIC;
    }
}

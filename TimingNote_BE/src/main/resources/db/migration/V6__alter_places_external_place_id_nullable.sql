-- external_place_id를 nullable로 변경
-- 집, 회사 등 지도 마커로 등록하는 사용자 정의 장소는 Kakao place ID가 없음
ALTER TABLE places
    ALTER COLUMN external_place_id DROP NOT NULL;

-- 기존 UNIQUE 제약 제거 후 조건부 인덱스로 교체
-- external_place_id가 존재할 때만 중복 방지 (NULL끼리는 허용)
ALTER TABLE places
    DROP CONSTRAINT IF EXISTS places_external_place_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_places_external_place_id
    ON places (external_place_id)
    WHERE external_place_id IS NOT NULL;

-- V8: user_places (user_id, alias_name) UNIQUE 제약 추가
--
-- 한 사용자가 같은 별칭으로 두 개 이상의 장소를 등록할 수 없도록 강제.
-- 서비스 레이어에서 사전 검증(USER_PLACE_NAME_DUPLICATED)을 수행하지만,
-- 동시성 race 상황(같은 별칭 동시 POST)에서 데이터 무결성을 지키는 안전망.
--
-- 주의: 운영 DB에 이미 중복 별칭이 존재하면 ALTER가 실패한다.
-- 적용 전 다음 쿼리로 확인:
--   SELECT user_id, alias_name, COUNT(*) FROM user_places
--   GROUP BY user_id, alias_name HAVING COUNT(*) > 1;
ALTER TABLE user_places
    ADD CONSTRAINT uq_user_places_user_id_alias_name
    UNIQUE (user_id, alias_name);

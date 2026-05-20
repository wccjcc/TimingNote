CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    installation_uuid UUID NOT NULL,
    device_secret VARCHAR(255) NOT NULL,
    last_seen_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE places (
    id BIGSERIAL PRIMARY KEY,
    external_place_id VARCHAR(128) NOT NULL,
    google_place_id VARCHAR(128) NULL,
    name VARCHAR(255) NOT NULL,
    category_name VARCHAR(100) NULL,
    address TEXT NULL,
    road_address TEXT NULL,
    location GEOGRAPHY(Point, 4326) NOT NULL,
    phone VARCHAR(50) NULL,
    place_url TEXT NULL,
    business_status VARCHAR(32) NULL,
    time_zone_id VARCHAR(64) NULL,
    utc_offset_minutes INTEGER NULL,
    regular_hours_raw JSONB NULL,
    hours_fetched_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE todos (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    primary_place_id BIGINT NULL,
    input_type VARCHAR(20) NOT NULL,
    todo_type VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,
    structure_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    category VARCHAR(20) NULL,
    content TEXT NOT NULL,
    resolved_place_label VARCHAR(255) NULL,
    alert_enabled BOOLEAN NOT NULL,
    snoozed_until TIMESTAMPTZ NULL,
    cooldown_until TIMESTAMPTZ NULL,
    completed_at TIMESTAMPTZ NULL,
    deleted_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE user_settings (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    location_alert_enabled BOOLEAN NOT NULL,
    push_alert_enabled BOOLEAN NOT NULL,
    radius_m INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE todo_structures (
    id BIGSERIAL PRIMARY KEY,
    todo_id BIGINT NOT NULL,
    todo_text VARCHAR(100) NULL,
    place_text VARCHAR(255) NULL,
    place_type VARCHAR(20) NULL,
    time_hint_text VARCHAR(255) NULL,
    category VARCHAR(20) NULL,
    raw_result_json JSONB NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    model_used VARCHAR(50) NOT NULL,
    request_id VARCHAR(50) NULL
);

CREATE TABLE todo_time_conditions (
    id BIGSERIAL PRIMARY KEY,
    todo_id BIGINT NOT NULL,
    condition_type VARCHAR(30) NOT NULL,
    start_date DATE NULL,
    end_date DATE NULL,
    start_time TIME NULL,
    end_time TIME NULL,
    days_of_week SMALLINT NULL,
    raw_expression VARCHAR(255) NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE todo_embeddings (
    id BIGSERIAL PRIMARY KEY,
    todo_id BIGINT NOT NULL,
    embedding_text TEXT NOT NULL,
    embedding VECTOR(1536) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE user_places (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    alias_name VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    place_id BIGINT NOT NULL
);

CREATE TABLE place_opening_periods (
    id BIGSERIAL PRIMARY KEY,
    place_id BIGINT NOT NULL,
    open_day SMALLINT NOT NULL,
    open_time TIME NOT NULL,
    close_day SMALLINT NULL,
    close_time TIME NULL,
    is_24h BOOLEAN NOT NULL,
    source_refreshed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE todo_candidate_places (
    id BIGSERIAL PRIMARY KEY,
    todo_id BIGINT NOT NULL,
    place_id BIGINT NOT NULL,
    distance_m INTEGER NOT NULL,
    score NUMERIC(8,4) NULL,
    is_monitoring_target BOOLEAN NOT NULL,
    calculated_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NULL
);

CREATE TABLE notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    todo_id BIGINT NOT NULL,
    candidate_place_id BIGINT NULL,
    notification_type VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,
    title VARCHAR(255) NULL,
    body TEXT NULL,
    opened_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE notification_actions (
    id BIGSERIAL PRIMARY KEY,
    notification_id BIGINT NOT NULL,
    action_type VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE todo_inputs (
    id BIGSERIAL PRIMARY KEY,
    todo_id BIGINT NOT NULL,
    input_type VARCHAR(20) NOT NULL,
    original_text TEXT NULL,
    image_url JSONB NULL,
    shared_url TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

ALTER TABLE users
    ADD CONSTRAINT uq_users_installation_uuid UNIQUE (installation_uuid);

ALTER TABLE users
    ADD CONSTRAINT uq_users_device_secret UNIQUE (device_secret);

ALTER TABLE user_settings
    ADD CONSTRAINT uq_user_settings_user_id UNIQUE (user_id);

ALTER TABLE places
    ADD CONSTRAINT uq_places_external_place_id UNIQUE (external_place_id);

ALTER TABLE todo_structures
    ADD CONSTRAINT uq_todo_structures_todo_id UNIQUE (todo_id);

ALTER TABLE todos
    ADD CONSTRAINT fk_todos_user
        FOREIGN KEY (user_id) REFERENCES users (id);

ALTER TABLE todos
    ADD CONSTRAINT fk_todos_primary_place
        FOREIGN KEY (primary_place_id) REFERENCES places (id);

ALTER TABLE user_settings
    ADD CONSTRAINT fk_user_settings_user
        FOREIGN KEY (user_id) REFERENCES users (id);

ALTER TABLE todo_structures
    ADD CONSTRAINT fk_todo_structures_todo
        FOREIGN KEY (todo_id) REFERENCES todos (id);

ALTER TABLE todo_time_conditions
    ADD CONSTRAINT fk_todo_time_conditions_todo
        FOREIGN KEY (todo_id) REFERENCES todos (id);

ALTER TABLE todo_embeddings
    ADD CONSTRAINT fk_todo_embeddings_todo
        FOREIGN KEY (todo_id) REFERENCES todos (id);

ALTER TABLE user_places
    ADD CONSTRAINT fk_user_places_user
        FOREIGN KEY (user_id) REFERENCES users (id);

ALTER TABLE user_places
    ADD CONSTRAINT fk_user_places_place
        FOREIGN KEY (place_id) REFERENCES places (id);

ALTER TABLE place_opening_periods
    ADD CONSTRAINT fk_place_opening_periods_place
        FOREIGN KEY (place_id) REFERENCES places (id);

ALTER TABLE todo_candidate_places
    ADD CONSTRAINT fk_todo_candidate_places_todo
        FOREIGN KEY (todo_id) REFERENCES todos (id);

ALTER TABLE todo_candidate_places
    ADD CONSTRAINT fk_todo_candidate_places_place
        FOREIGN KEY (place_id) REFERENCES places (id);

ALTER TABLE notifications
    ADD CONSTRAINT fk_notifications_user
        FOREIGN KEY (user_id) REFERENCES users (id);

ALTER TABLE notifications
    ADD CONSTRAINT fk_notifications_todo
        FOREIGN KEY (todo_id) REFERENCES todos (id);

ALTER TABLE notifications
    ADD CONSTRAINT fk_notifications_candidate_place
        FOREIGN KEY (candidate_place_id) REFERENCES todo_candidate_places (id);

ALTER TABLE notification_actions
    ADD CONSTRAINT fk_notification_actions_notification
        FOREIGN KEY (notification_id) REFERENCES notifications (id);

ALTER TABLE todo_inputs
    ADD CONSTRAINT fk_todo_inputs_todo
        FOREIGN KEY (todo_id) REFERENCES todos (id);

CREATE INDEX idx_users_device_secret
    ON users (device_secret);

CREATE INDEX idx_todos_user_id
    ON todos (user_id);

CREATE INDEX idx_todos_status
    ON todos (status);

CREATE INDEX idx_todos_deleted_at
    ON todos (deleted_at);

CREATE INDEX idx_todo_structures_todo_id
    ON todo_structures (todo_id);

CREATE INDEX idx_todo_time_cond_todo_id
    ON todo_time_conditions (todo_id);

CREATE INDEX idx_todo_cand_places_todo_id
    ON todo_candidate_places (todo_id);

CREATE INDEX idx_notifications_user_id
    ON notifications (user_id);

CREATE INDEX idx_notifications_todo_id
    ON notifications (todo_id);

CREATE INDEX idx_user_places_user_id
    ON user_places (user_id);

CREATE INDEX idx_todo_inputs_todo_id
    ON todo_inputs (todo_id);


CREATE TABLE user_fcm_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    fcm_token VARCHAR(255) NOT NULL,
    platform VARCHAR(20) NOT NULL,
    is_active BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

ALTER TABLE user_fcm_tokens
    ADD CONSTRAINT fk_user_fcm_tokens_user
        FOREIGN KEY (user_id) REFERENCES users (id);

ALTER TABLE user_fcm_tokens
    ADD CONSTRAINT uq_user_fcm_tokens_fcm_token UNIQUE (fcm_token);

CREATE INDEX idx_user_fcm_tokens_user_id
    ON user_fcm_tokens (user_id);

CREATE INDEX idx_user_fcm_tokens_user_active
    ON user_fcm_tokens (user_id, is_active);

ALTER TABLE places
    ADD COLUMN IF NOT EXISTS category_group_code VARCHAR(10) NULL,
    ADD COLUMN IF NOT EXISTS category_group_name VARCHAR(50) NULL,
    DROP COLUMN IF EXISTS time_zone_id,
    DROP COLUMN IF EXISTS utc_offset_minutes;

DROP TABLE IF EXISTS notification_actions;

CREATE TABLE IF NOT EXISTS geofence_slots (
    id BIGSERIAL NOT NULL,
    user_id BIGINT NOT NULL,
    place_id BIGINT NOT NULL,
    todo_id BIGINT NOT NULL,
    caculated_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS geofence_recalculate_outbox (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    latitude NUMERIC(10, 7) NULL,
    longitude NUMERIC(10, 7) NULL,
    course NUMERIC(7, 3) NULL,
    status VARCHAR(20) NOT NULL,
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retry_count INTEGER NOT NULL DEFAULT 5,
    next_retry_at TIMESTAMPTZ NOT NULL,
    last_error TEXT NULL,
    published_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_geofence_outbox_status_next_retry
    ON geofence_recalculate_outbox (status, next_retry_at, id);

CREATE INDEX IF NOT EXISTS idx_geofence_outbox_user_id
    ON geofence_recalculate_outbox (user_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_geofence_slots_user_todo_place
    ON geofence_slots (user_id, todo_id, place_id);


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

-- V7: 성능 최적화를 위한 인덱스 추가
--
-- [1] todos 복합 인덱스: findTodoPage (user_id + status 동시 필터)
--     기존 단일 인덱스(idx_todos_user_id, idx_todos_status)는 유지하되
--     복합 조건 쿼리의 탐색 효율 개선을 위해 추가.
CREATE INDEX IF NOT EXISTS idx_todos_user_id_status
    ON todos (user_id, status);

-- [2] places 공간 인덱스: PostGIS ST_Distance / ST_DWithin 최적화
--     places.location = GEOGRAPHY(Point, 4326) 이지만 공간 인덱스가 없으면
--     findMonitoringCandidateDistancesByUserId의 ST_Distance 계산이 Full Table Scan.
CREATE INDEX IF NOT EXISTS idx_places_location
    ON places USING GIST (location);

-- [3] geofence_slots 사용자 조회 인덱스: findByUserId 최적화
--     GeofenceSlotManagerImpl.recalculateSlots()에서 매 재계산마다 호출.
CREATE INDEX IF NOT EXISTS idx_geofence_slots_user_id
    ON geofence_slots (user_id);

-- [4] todo_candidate_places 모니터링 후보 Partial Index
--     findMonitoringCandidatesByUserId: is_monitoring_target = true 인 행만 탐색.
--     Partial Index로 false 행 제외 → 인덱스 크기 절감 + 탐색 효율 향상.
CREATE INDEX IF NOT EXISTS idx_tcp_monitoring_target_expires
    ON todo_candidate_places (is_monitoring_target, expires_at)
    WHERE is_monitoring_target = true;

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

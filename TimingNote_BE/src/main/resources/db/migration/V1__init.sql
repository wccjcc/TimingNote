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
    image_url TEXT[] NULL,
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

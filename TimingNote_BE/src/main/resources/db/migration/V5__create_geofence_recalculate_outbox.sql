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


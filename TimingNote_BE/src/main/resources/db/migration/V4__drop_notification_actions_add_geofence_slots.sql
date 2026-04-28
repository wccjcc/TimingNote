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

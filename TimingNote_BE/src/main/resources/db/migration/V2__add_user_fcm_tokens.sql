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

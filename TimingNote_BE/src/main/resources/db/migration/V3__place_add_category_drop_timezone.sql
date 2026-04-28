ALTER TABLE places
    ADD COLUMN IF NOT EXISTS category_group_code VARCHAR(10) NULL,
    ADD COLUMN IF NOT EXISTS category_group_name VARCHAR(50) NULL,
    DROP COLUMN IF EXISTS time_zone_id,
    DROP COLUMN IF EXISTS utc_offset_minutes;

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

package com.timingnote.api.domain.place.entity;

import com.timingnote.api.domain.todo.entity.Todo;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Builder
@Table(name = "todo_candidate_places")
public class TodoCandidatePlace {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "todo_id", nullable = false)
    private Todo todo;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "place_id", nullable = false)
    private Place place;

    // 후보 계산 시점의 사용자 ↔ 장소 거리 (m)
    @Column(name = "distance_m", nullable = false)
    private Integer distanceM;

    // 매칭 신뢰도 (0.0000~1.0000, nullable)
    @Column(name = "score", precision = 8, scale = 4)
    private BigDecimal score;

    // Geofence 등록 대상 여부 (BE-017에서 갱신 가능)
    @Column(name = "is_monitoring_target", nullable = false)
    @Builder.Default
    private boolean isMonitoringTarget = true;

    // 후보 계산(저장) 시각
    @Column(name = "calculated_at", nullable = false)
    private OffsetDateTime calculatedAt;

    // 후보 만료 시각 (BE-017 재계산 기준, nullable)
    // null = 유효, not null = 만료 (슬롯 계산 대상에서 제외)
    @Column(name = "expires_at")
    private OffsetDateTime expiresAt;

    /**
     * 유의미한 이동 후 동일 장소가 새 검색 결과에 다시 포함된 경우 재활성화한다.
     * 새 위치 기준 거리로 갱신하고 만료를 해제한다 (expiresAt = null).
     */
    public void reactivate(int distanceM, OffsetDateTime calculatedAt) {
        this.distanceM = distanceM;
        this.calculatedAt = calculatedAt;
        this.expiresAt = null;
    }

    /**
     * 유의미한 이동 후 새 검색 결과에 포함되지 않은 장소를 만료 처리한다.
     * 슬롯 계산 시 expiresAt 필터에 의해 자동 제외된다.
     */
    public void expire(OffsetDateTime now) {
        this.expiresAt = now;
    }
}

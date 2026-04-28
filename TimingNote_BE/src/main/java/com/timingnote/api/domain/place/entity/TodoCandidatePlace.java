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
    @Column(name = "expires_at")
    private OffsetDateTime expiresAt;
}

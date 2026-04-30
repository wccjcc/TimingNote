package com.timingnote.api.domain.todo.entity;

import com.timingnote.api.infra.client.ai.AiPlaceType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.Map;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Builder
@Table(name = "todo_structures")
public class TodoStructure {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "todo_id", nullable = false)
    private Todo todo;

    @Column(name = "todo_text", length = 100)
    private String todoText;

    @Column(name = "place_text")
    private String placeText;

    @Column(name = "place_type", length = 20)
    @Enumerated(EnumType.STRING)
    private AiPlaceType placeType;

    @Column(name = "time_hint_text")
    private String timeHintText;

    @Column(name = "category", length = 20)
    private String category;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "raw_result_json", columnDefinition = "jsonb")
    private Map<String, Object> rawResultJson;

    @Column(name = "model_used", length = 50, nullable = false)
    private String modelUsed;

    @Column(name = "request_id", length = 50)
    private String requestId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false, nullable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    // ── 도메인 메서드 ─────────────────────────────────────────────────────────

    /** 사용자가 장소를 직접 수정할 때 placeText와 placeType을 갱신한다. */
    public void updatePlaceInfo(String placeText, AiPlaceType placeType) {
        this.placeText = placeText;
        this.placeType = placeType;
    }
}

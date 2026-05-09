package com.timingnote.api.domain.todo.entity;

import com.timingnote.api.domain.todo.enums.InputType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.List;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Builder
@Table(name = "todo_inputs")
public class TodoInput {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "todo_id", nullable = false)
    private Todo todo;

    @Enumerated(EnumType.STRING)
    @Column(name = "input_type", length = 20, nullable = false)
    private InputType inputType;

    // TEXT: 사용자 입력 원문 / VOICE: STT 변환 텍스트
    @Column(name = "original_text", columnDefinition = "TEXT")
    private String originalText;

    // IMAGE: 업로드된 이미지 URL 목록 (jsonb 저장 — TEXT[] 대신 사용)
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "image_url", columnDefinition = "jsonb")
    private List<String> imageUrl;

    // LINK: 공유된 URL
    @Column(name = "shared_url", columnDefinition = "TEXT")
    private String sharedUrl;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false, nullable = false)
    private OffsetDateTime createdAt;

    public void updateImageUrl(List<String> imageUrl) {
        this.imageUrl = imageUrl;
    }
}

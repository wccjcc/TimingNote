package com.timingnote.api.domain.todo.search.document;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.elasticsearch.annotations.DateFormat;
import org.springframework.data.elasticsearch.annotations.Document;
import org.springframework.data.elasticsearch.annotations.Field;
import org.springframework.data.elasticsearch.annotations.FieldType;

import java.time.OffsetDateTime;

/**
 * 할 일 검색 ES 도큐먼트.
 *
 * <p>인덱스 매핑·분석기 정의는 {@code resources/elasticsearch/todos-{settings,mappings}.json}에서 관리하며,
 * Spring Data ES 자동 매핑 생성은 비활성화한다(createIndex=false, writeTypeHint=FALSE).
 *
 * <p>{@code _id}는 todoId의 문자열 표현을 사용해 동일 ID로 upsert 시 멱등 보장.
 * indexName은 alias({@code app.search.todo-index})를 가리키며, 실제 물리 인덱스는
 * {@link com.timingnote.api.domain.todo.search.config.SearchProperties#physicalIndexName()}.
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(indexName = "#{@searchProperties.todoIndex}", createIndex = false, writeTypeHint = org.springframework.data.elasticsearch.annotations.WriteTypeHint.FALSE)
public class TodoSearchDocument {

    @Id
    private String id;

    private String userId;
    private String content;
    private String placeLabel;
    private String placeName;
    private String status;
    private String category;
    private String todoType;
    private String structureStatus;
    private Long primaryPlaceId;

    // Spring Data ES의 직렬화 컨버터가 OffsetDateTime을 처리하려면 @Field(type=Date)가 필요.
    // @JsonFormat은 ES 마샬러가 보지 않으므로 단독으로는 색인 시 필드 누락됨.
    @Field(type = FieldType.Date, format = DateFormat.date_time)
    @JsonFormat(shape = JsonFormat.Shape.STRING)
    private OffsetDateTime createdAt;

    @Field(type = FieldType.Date, format = DateFormat.date_time)
    @JsonFormat(shape = JsonFormat.Shape.STRING)
    private OffsetDateTime completedAt;

    @Field(type = FieldType.Date, format = DateFormat.date_time)
    @JsonFormat(shape = JsonFormat.Shape.STRING)
    private OffsetDateTime deletedAt;
}

package com.timingnote.api.domain.todo.service;

import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
import com.timingnote.api.domain.todo.dto.response.TodoCreateResponse;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.entity.TodoStructure;
import com.timingnote.api.domain.todo.entity.TodoTimeCondition;
import com.timingnote.api.domain.todo.repository.TodoRepository;
import com.timingnote.api.domain.todo.repository.TodoStructureRepository;
import com.timingnote.api.domain.todo.repository.TodoTimeConditionRepository;
import com.timingnote.api.infra.client.ai.AiPlaceType;
import com.timingnote.api.infra.client.ai.AiClient;
import com.timingnote.api.infra.client.ai.dto.AiStructureRequest;
import com.timingnote.api.infra.client.ai.dto.AiStructureResponse;
import com.timingnote.api.infra.client.ai.dto.AiTimeCondition;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class TodoServiceImpl implements TodoService {

    private final TodoRepository todoRepository;
    private final TodoStructureRepository todoStructureRepository;
    private final TodoTimeConditionRepository todoTimeConditionRepository;
    private final AiClient aiClient;

    // @Lazy 자기 참조: doOnSuccess 콜백에서 @Transactional 프록시를 통해 호출하기 위함
    @Lazy
    @Autowired
    private TodoService self;

    @Override
    @Transactional
    public TodoCreateResponse createTodo(Long userId, TodoCreateRequest request) {
        Todo todo = Todo.builder()
                .userId(userId)
                .content(request.getContent())
                .inputType(request.getInputType())
                .todoType("MEMO")
                .status("ACTIVE")
                .structureStatus("PENDING")
                .alertEnabled(true)
                .build();

        Todo savedTodo = todoRepository.save(todo);

        triggerAiAnalysis(savedTodo.getId(), savedTodo.getInputType(), savedTodo.getContent());

        return TodoCreateResponse.builder()
                .todoId(savedTodo.getId())
                .status(savedTodo.getStatus())
                .structureStatus(savedTodo.getStructureStatus())
                .createdAt(savedTodo.getCreatedAt())
                .build();
    }

    private void triggerAiAnalysis(Long todoId, String inputType, String content) {
        AiStructureRequest aiRequest = AiStructureRequest.builder()
                .todoId(todoId)
                .inputType(inputType)
                .originalText(content)
                .build();

        aiClient.structureMemo(aiRequest)
                .doOnSuccess(response -> {
                    if (response != null) {
                        self.saveStructure(todoId, response);
                    }
                })
                .doOnError(e -> {
                    log.error("[AI] 구조화 실패 (todoId={}): {}", todoId, e.getMessage());
                    self.markStructureFailed(todoId);
                })
                .subscribe();
    }

    @Override
    @Transactional
    public void saveStructure(Long todoId, AiStructureResponse response) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new IllegalStateException("Todo not found: " + todoId));

        // 1. AiPlaceType 변환 (파싱 실패 시 NONE으로 fallback)
        AiPlaceType placeType = parseEnum(AiPlaceType.class, response.getPlaceType(), AiPlaceType.GENERAL);

        // 2. TodoStructure 저장
        TodoStructure structure = TodoStructure.builder()
                .todo(todo)
                .todoText(response.getTodoText())
                .category(response.getCategory())
                .placeType(placeType)
                .placeText(response.getPlaceText())
                .timeHintText(response.getTimeHintText())
                .modelUsed(response.getModelUsed() != null ? response.getModelUsed() : "unknown")
                .requestId(response.getRequestId())
                .rawResultJson(response.getRawResultJson())
                .build();

        todoStructureRepository.save(structure);

        // 4. 시간 조건 저장 (todo_time_conditions)
        List<AiTimeCondition> timeConditions = response.getTimeConditions();
        if (timeConditions != null && !timeConditions.isEmpty()) {
            List<TodoTimeCondition> conditions = timeConditions.stream()
                    .map(tc -> TodoTimeCondition.builder()
                            .todo(todo)
                            .conditionType(tc.getConditionType())
                            .startDate(parseDate(tc.getStartDate()))
                            .endDate(parseDate(tc.getEndDate()))
                            .startTime(parseTime(tc.getStartTime()))
                            .endTime(parseTime(tc.getEndTime()))
                            .daysOfWeek(toDayBitmask(tc.getDaysOfWeek()))
                            .rawExpression(tc.getRawExpression())
                            .build())
                    .toList();
            todoTimeConditionRepository.saveAll(conditions);
        }

        // 5. Todo 업데이트: todoType(place_type 기반 도출), category, resolvedPlaceLabel, structureStatus
        todo.updateTodoType(resolveTodoType(placeType));
        if (StringUtils.hasText(response.getCategory())) {
            todo.updateCategory(response.getCategory());
        }
        if (StringUtils.hasText(response.getPlaceText())) {
            todo.updateResolvedPlaceLabel(response.getPlaceText());
        }
        todo.updateStructureStatus("READY");

        log.info("[AI] 구조화 저장 완료 (todoId={}, todoType={}, placeType={})",
                todoId, resolveTodoType(placeType), placeType);
    }

    @Override
    @Transactional
    public void markStructureFailed(Long todoId) {
        todoRepository.findById(todoId).ifPresent(todo -> {
            todo.updateStructureStatus("FAILED");
            log.warn("[AI] 구조화 FAILED 처리 (todoId={})", todoId);
        });
    }

    private <E extends Enum<E>> E parseEnum(Class<E> enumClass, String value, E fallback) {
        if (!StringUtils.hasText(value)) return fallback;
        try {
            return Enum.valueOf(enumClass, value);
        } catch (IllegalArgumentException e) {
            log.warn("[AI] 알 수 없는 enum 값 '{}' → {} 로 fallback", value, fallback);
            return fallback;
        }
    }

    private String resolveTodoType(AiPlaceType placeType) {
        return switch (placeType) {
            case SPECIFIC -> "SPECIFIC";
            case GENERIC  -> "GENERIC";
            case ALIAS    -> "ALIAS";
            case GENERAL  -> "GENERAL";
        };
    }

    private Integer toDayBitmask(List<String> days) {
        if (days == null || days.isEmpty()) return null;
        int[] bits = {0, 1, 2, 4, 8, 16, 32, 64}; // index unused, MON=1...SUN=64
        java.util.Map<String, Integer> map = java.util.Map.of(
                "MON", 1, "TUE", 2, "WED", 4, "THU", 8, "FRI", 16, "SAT", 32, "SUN", 64);
        return days.stream()
                .map(d -> map.getOrDefault(d.toUpperCase(), 0))
                .reduce(0, (a, b) -> a | b);
    }

    private LocalDate parseDate(String value) {
        if (!StringUtils.hasText(value)) return null;
        try {
            return LocalDate.parse(value);
        } catch (DateTimeParseException e) {
            log.warn("[AI] 날짜 파싱 실패: {}", value);
            return null;
        }
    }

    private LocalTime parseTime(String value) {
        if (!StringUtils.hasText(value)) return null;
        try {
            return LocalTime.parse(value);
        } catch (DateTimeParseException e) {
            log.warn("[AI] 시간 파싱 실패: {}", value);
            return null;
        }
    }
}

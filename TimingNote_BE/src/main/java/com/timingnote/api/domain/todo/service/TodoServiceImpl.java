package com.timingnote.api.domain.todo.service;

import com.timingnote.api.common.exception.BusinessException;
import com.timingnote.api.common.exception.ErrorCode;
import com.timingnote.api.domain.place.entity.Place;
import com.timingnote.api.domain.place.entity.TodoCandidatePlace;
import com.timingnote.api.domain.place.repository.PlaceRepository;
import com.timingnote.api.domain.place.repository.TodoCandidatePlaceRepository;
import com.timingnote.api.domain.place.service.PlaceService;
import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
import com.timingnote.api.domain.todo.dto.response.TodoCreateResponse;
import com.timingnote.api.domain.todo.dto.response.TodoDetailResponse;
import com.timingnote.api.domain.todo.dto.response.TodoListItemResponse;
import com.timingnote.api.domain.todo.dto.response.TodoListResponse;
import com.timingnote.api.domain.todo.entity.Todo;
import com.timingnote.api.domain.todo.entity.TodoInput;
import com.timingnote.api.domain.todo.entity.TodoStructure;
import com.timingnote.api.domain.todo.entity.TodoTimeCondition;
import com.timingnote.api.domain.todo.repository.TodoInputRepository;
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
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import reactor.core.scheduler.Schedulers;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Slf4j
@Service
@RequiredArgsConstructor
public class TodoServiceImpl implements TodoService {

    private final TodoRepository todoRepository;
    private final TodoInputRepository todoInputRepository;
    private final TodoStructureRepository todoStructureRepository;
    private final TodoTimeConditionRepository todoTimeConditionRepository;
    private final TodoCandidatePlaceRepository todoCandidatePlaceRepository;
    private final PlaceRepository placeRepository;
    private final AiClient aiClient;
    private final PlaceService placeService;

    // 요일 → 비트마스크 변환 테이블 (MON=1, TUE=2, WED=4, THU=8, FRI=16, SAT=32, SUN=64)
    private static final Map<String, Integer> DAY_BITMASK = Map.of(
            "MON", 1, "TUE", 2, "WED", 4,
            "THU", 8, "FRI", 16, "SAT", 32, "SUN", 64);

    // @Lazy 자기 참조: subscribe() 콜백에서 @Transactional 프록시를 통해 호출하기 위함
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
                .todoType("GENERAL")  // AI 구조화 전 기본값, saveStructure()에서 갱신
                .status("ACTIVE")
                .structureStatus("PENDING")
                .alertEnabled(true)
                .build();

        Todo savedTodo = todoRepository.save(todo);

        // 원본 입력 보관 (inputType별 필드 분기 — VOICE/IMAGE/LINK는 추후 확장)
        todoInputRepository.save(TodoInput.builder()
                .todo(savedTodo)
                .inputType(savedTodo.getInputType())
                .originalText(savedTodo.getContent())
                .build());

        triggerAiAnalysis(savedTodo.getId(), savedTodo.getInputType(), savedTodo.getContent(),
                request.getLatitude(), request.getLongitude());

        return TodoCreateResponse.builder()
                .todoId(savedTodo.getId())
                .status(savedTodo.getStatus())
                .structureStatus(savedTodo.getStructureStatus())
                .createdAt(savedTodo.getCreatedAt())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public TodoListResponse getTodoList(Long userId, String status, String tab, String placeType, Long cursor, int limit) {
        List<Todo> fetched = todoRepository.findTodoPage(
                userId, status, tab, placeType, cursor, PageRequest.of(0, limit + 1));

        boolean hasNext = fetched.size() > limit;
        List<Todo> page = hasNext ? fetched.subList(0, limit) : fetched;

        List<Long> todoIds = page.stream().map(Todo::getId).toList();
        Map<Long, String> thumbnailMap = fetchThumbnails(todoIds);

        List<TodoListItemResponse> items = page.stream()
                .map(todo -> TodoListItemResponse.from(todo, thumbnailMap.get(todo.getId())))
                .toList();

        return TodoListResponse.builder()
                .items(items)
                .nextCursor(hasNext ? page.get(page.size() - 1).getId() : null)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public TodoDetailResponse getTodoDetail(Long userId, Long todoId) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));

        if (!todo.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN);
        }

        TodoStructure structure = todoStructureRepository.findByTodo_Id(todoId).orElse(null);
        List<TodoTimeCondition> timeConditions =
                todoTimeConditionRepository.findAllByTodo_Id(todoId);
        Place primaryPlace = (todo.getPrimaryPlaceId() != null)
                ? placeRepository.findById(todo.getPrimaryPlaceId()).orElse(null)
                : null;
        List<String> imageUrls = todoInputRepository
                .findAllByTodo_IdAndImageUrlIsNotNullOrderByIdAsc(todoId)
                .stream()
                .flatMap(input -> input.getImageUrl().stream())
                .limit(3)
                .toList();
        String sharedUrl = todoInputRepository
                .findFirstByTodo_IdAndSharedUrlIsNotNull(todoId)
                .map(TodoInput::getSharedUrl)
                .orElse(null);

        return TodoDetailResponse.of(todo, structure, timeConditions, primaryPlace, imageUrls, sharedUrl);
    }

    private Map<Long, String> fetchThumbnails(List<Long> todoIds) {
        if (todoIds.isEmpty()) return Map.of();
        return todoInputRepository.findAllByTodo_IdInAndImageUrlIsNotNullOrderByIdAsc(todoIds)
                .stream()
                .filter(input -> !input.getImageUrl().isEmpty())
                .collect(Collectors.toMap(
                        input -> input.getTodo().getId(),
                        input -> input.getImageUrl().get(0),
                        (a, b) -> a  // 동일 todoId에 IMAGE input이 복수일 경우 첫 번째 유지
                ));
    }

    private void triggerAiAnalysis(Long todoId, String inputType, String content,
                                   Double latitude, Double longitude) {
        AiStructureRequest aiRequest = AiStructureRequest.builder()
                .todoId(todoId)
                .inputType(inputType)
                .originalText(content)
                // TODO: user_places 구현 후 userId 기반으로 별칭 목록 조회하여 주입
                .build();

        aiClient.structureMemo(aiRequest)
                .subscribe(
                        response -> {
                            if (response == null) return;
                            // reactor-http-nio 스레드에서 .block() 금지 → boundedElastic 으로 직접 스케줄링
                            // publishOn 은 WebClientAdapter 내부 operator fusion 으로 무력화될 수 있어
                            // schedule() 은 확실하게 해당 스레드 풀에서 실행 보장
                            Schedulers.boundedElastic().schedule(
                                    () -> self.saveStructure(todoId, response, latitude, longitude)
                            );
                        },
                        e -> {
                            log.error("[AI] 구조화 실패 (todoId={}): {}", todoId, e.getMessage());
                            Schedulers.boundedElastic().schedule(
                                    () -> self.markStructureFailed(todoId)
                            );
                        }
                );
    }

    @Override
    @Transactional
    public void saveStructure(Long todoId, AiStructureResponse response, Double latitude, Double longitude) {
        Todo todo = todoRepository.findById(todoId)
                .orElseThrow(() -> new IllegalStateException("Todo not found: " + todoId));

        // 1. AiPlaceType 변환 (파싱 실패 시 GENERAL로 fallback)
        AiPlaceType placeType = parseEnum(AiPlaceType.class, response.getPlaceType(), AiPlaceType.GENERAL);
        String todoType = placeType.name();

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

        // 3. 시간 조건 저장
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

        // 4. 장소 연동 (placeType에 따라 분기)
        String placeText = response.getPlaceText();
        if (placeType == AiPlaceType.SPECIFIC && StringUtils.hasText(placeText)) {
            // SPECIFIC: 좌표 없어도 Kakao 전국 accuracy 검색 시도 (지점명 포함이라 정확도 충분)
            // 위치 권한이 없어도 place 저장 → Geofence 등록은 알림 서버가 처리
            // (진입 감지는 OS가 위치 권한 필요 → 알림 서버에서 권한 요청 메시지 발송)
            placeService.resolveSpecificPlace(placeText, latitude, longitude)
                    .ifPresent(place -> todo.updatePrimaryPlaceId(place.getId()));

        } else if (placeType == AiPlaceType.GENERIC
                && StringUtils.hasText(placeText)
                && latitude != null && longitude != null) {
            // GENERIC: 반경 검색이므로 좌표 필수. 위치 권한 없으면 스킵.
            List<Place> candidates = placeService.resolveGenericCandidates(placeText, latitude, longitude);
            if (!candidates.isEmpty()) {
                java.time.OffsetDateTime now = java.time.OffsetDateTime.now();
                List<TodoCandidatePlace> candidatePlaces = candidates.stream()
                        .map(place -> TodoCandidatePlace.builder()
                                .todo(todo)
                                .place(place)
                                .distanceM(haversineMeters(
                                        latitude, longitude,
                                        place.getLatitude(), place.getLongitude()))
                                .isMonitoringTarget(true)
                                .calculatedAt(now)
                                .build())
                        .toList();
                todoCandidatePlaceRepository.saveAll(candidatePlaces);
                log.info("[Place] GENERIC 후보 {} 개 저장 (todoId={})", candidates.size(), todoId);
            }

        } else if (placeType == AiPlaceType.GENERIC && (latitude == null || longitude == null)) {
            log.info("[Place] GENERIC — 위치 권한 없음, 장소 연동 스킵 (todoId={}, placeText={})", todoId, placeText);
        }

        // 5. Todo 상태 갱신
        todo.updateTodoType(todoType);
        if (StringUtils.hasText(response.getCategory())) {
            todo.updateCategory(response.getCategory());
        }
        if (StringUtils.hasText(placeText)) {
            todo.updateResolvedPlaceLabel(placeText);
        }
        todo.updateStructureStatus("READY");

        log.info("[AI] 구조화 저장 완료 (todoId={}, todoType={}, placeType={})", todoId, todoType, placeType);
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

    private Short toDayBitmask(List<String> days) {
        if (days == null || days.isEmpty()) return null;
        int mask = days.stream()
                .map(d -> DAY_BITMASK.getOrDefault(d.toUpperCase(), 0))
                .reduce(0, (a, b) -> a | b);
        return mask == 0 ? null : (short) mask;
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

    /** Haversine 공식으로 두 좌표 간 거리(m) 계산 */
    private static int haversineMeters(double lat1, double lon1, double lat2, double lon2) {
        final double R = 6_371_000.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return (int) Math.round(R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
    }
}

package com.timingnote.api.domain.todo.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.timingnote.api.common.exception.GlobalExceptionHandler;
import com.timingnote.api.domain.todo.dto.request.TodoCreateRequest;
import com.timingnote.api.domain.todo.dto.request.TodoPlaceSetRequest;
import com.timingnote.api.domain.todo.dto.request.TodoStatusUpdateRequest;
import com.timingnote.api.domain.todo.dto.response.TodoCreateResponse;
import com.timingnote.api.domain.todo.dto.response.TodoDetailResponse;
import com.timingnote.api.domain.todo.dto.response.TodoListResponse;
import com.timingnote.api.domain.todo.enums.StructureStatus;
import com.timingnote.api.domain.todo.enums.TodoStatus;
import com.timingnote.api.domain.todo.enums.TodoType;
import com.timingnote.api.domain.todo.service.TodoService;
import com.timingnote.api.infra.security.DeviceSecretAuthInterceptor;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

@ExtendWith(MockitoExtension.class)
class TodoControllerTest {

    private static final Long USER_ID = 10L;
    private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-05-26T10:00:00+09:00");

    @Mock
    private TodoService todoService;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders
                .standaloneSetup(new TodoController(todoService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void createTodo_extractsAuthenticatedUserId_andReturnsSuccessResponse() throws Exception {
        TodoCreateResponse response = TodoCreateResponse.builder()
                .todoId(101L)
                .status(TodoStatus.ACTIVE.name())
                .structureStatus(StructureStatus.PENDING.name())
                .createdAt(NOW)
                .build();
        when(todoService.createTodo(eq(USER_ID), any(TodoCreateRequest.class))).thenReturn(response);

        mockMvc.perform(post("/api/v1/todos")
                        .requestAttr(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID, USER_ID)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "content": "약국 들르기",
                                  "inputType": "TEXT",
                                  "latitude": 37.5665,
                                  "longitude": 126.9780,
                                  "course": 120.0,
                                  "occurredAt": "2026-05-26T10:00:00+09:00"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.todoId").value(101));

        ArgumentCaptor<TodoCreateRequest> requestCaptor = ArgumentCaptor.forClass(TodoCreateRequest.class);
        verify(todoService).createTodo(eq(USER_ID), requestCaptor.capture());
        TodoCreateRequest request = requestCaptor.getValue();
        assertThat(request.getContent()).isEqualTo("약국 들르기");
        assertThat(request.getInputType()).isEqualTo("TEXT");
        assertThat(request.getLatitude()).isEqualTo(37.5665);
    }

    @Test
    void getTodoList_capsLimitToFifty_andDelegatesQueryParameters() throws Exception {
        when(todoService.getTodoList(
                USER_ID,
                "ACTIVE",
                "HEALTH",
                "GENERIC",
                99L,
                50,
                37.5665,
                126.9780,
                120.0,
                OffsetDateTime.parse("2026-05-26T01:00:00Z")
        )).thenReturn(TodoListResponse.builder()
                .items(List.of())
                .nextCursor(null)
                .build());

        mockMvc.perform(get("/api/v1/todos")
                        .requestAttr(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID, USER_ID)
                        .param("status", "ACTIVE")
                        .param("tab", "HEALTH")
                        .param("placeType", "GENERIC")
                        .param("cursor", "99")
                        .param("limit", "200")
                        .param("latitude", "37.5665")
                        .param("longitude", "126.9780")
                        .param("course", "120.0")
                        .param("occurredAt", "2026-05-26T01:00:00Z"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.items").isArray());

        verify(todoService).getTodoList(
                USER_ID,
                "ACTIVE",
                "HEALTH",
                "GENERIC",
                99L,
                50,
                37.5665,
                126.9780,
                120.0,
                OffsetDateTime.parse("2026-05-26T01:00:00Z")
        );
    }

    @Test
    void updateStatus_extractsAuthenticatedUserId_andDelegatesBody() throws Exception {
        mockMvc.perform(patch("/api/v1/todos/{todoId}/status", 101L)
                        .requestAttr(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID, USER_ID)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "DONE",
                                  "latitude": 37.5665,
                                  "longitude": 126.9780,
                                  "course": 120.0,
                                  "occurredAt": "2026-05-26T10:00:00+09:00"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));

        ArgumentCaptor<TodoStatusUpdateRequest> requestCaptor =
                ArgumentCaptor.forClass(TodoStatusUpdateRequest.class);
        verify(todoService).updateStatus(eq(USER_ID), eq(101L), requestCaptor.capture());
        TodoStatusUpdateRequest request = requestCaptor.getValue();
        assertThat(request.getStatus()).isEqualTo(TodoStatus.DONE.name());
        assertThat(request.getLatitude()).isEqualTo(37.5665);
    }

    @Test
    void deleteTodos_parsesIdsAndLocationParameters() throws Exception {
        mockMvc.perform(delete("/api/v1/todos")
                        .requestAttr(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID, USER_ID)
                        .param("ids", "101", "102")
                        .param("latitude", "37.5665")
                        .param("longitude", "126.9780")
                        .param("course", "120.0")
                        .param("occurredAt", "2026-05-26T01:00:00Z"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));

        verify(todoService).deleteTodos(
                USER_ID,
                List.of(101L, 102L),
                37.5665,
                126.9780,
                120.0,
                OffsetDateTime.parse("2026-05-26T01:00:00Z")
        );
    }

    @Test
    void setTodoPlace_delegatesAliasSelection() throws Exception {
        when(todoService.setTodoPlace(eq(USER_ID), eq(101L), any(TodoPlaceSetRequest.class)))
                .thenReturn(TodoDetailResponse.builder()
                        .id(101L)
                        .todoType(TodoType.ALIAS.name())
                        .resolvedPlaceLabel("집")
                        .build());

        mockMvc.perform(post("/api/v1/todos/{todoId}/place", 101L)
                        .requestAttr(DeviceSecretAuthInterceptor.AUTHENTICATED_USER_ID, USER_ID)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "userPlaceId": 301,
                                  "latitude": 37.5665,
                                  "longitude": 126.9780
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.todoType").value("ALIAS"));

        verify(todoService).setTodoPlace(eq(USER_ID), eq(101L), any(TodoPlaceSetRequest.class));
    }

    @Test
    void removeTodoPlace_requiresAuthenticatedUserId() throws Exception {
        mockMvc.perform(delete("/api/v1/todos/{todoId}/place", 101L))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").exists());

        verify(todoService, never()).removeTodoPlace(any(), any());
    }
}

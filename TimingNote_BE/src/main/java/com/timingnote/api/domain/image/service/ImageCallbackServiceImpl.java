package com.timingnote.api.domain.image.service;

import com.timingnote.api.domain.image.dto.request.ImageResizeCallbackRequestDto;
import com.timingnote.api.domain.todo.entity.TodoInput;
import com.timingnote.api.domain.todo.repository.TodoInputRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * Lambda 리사이즈 콜백 처리 서비스
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ImageCallbackServiceImpl implements ImageCallbackService {

    private final TodoInputRepository todoInputRepository;

    @Override
    @Transactional
    public void handleResizeCallback(ImageResizeCallbackRequestDto request) {
        String status = request.getStatus();
        if (!"SUCCESS".equalsIgnoreCase(status)) {
            // FAILED 포함 비성공 상태는 수신만 기록하고 종료한다.
            log.warn("[Image/Callback] non-success status={} originalKey={} error={}",
                    status, request.getOriginalKey(), request.getErrorMessage());
            return;
        }

        if (!StringUtils.hasText(request.getResizedKey())) {
            log.warn("[Image/Callback] resizedKey missing on success. originalKey={}", request.getOriginalKey());
            return;
        }

        List<TodoInput> targets = todoInputRepository.findAllByImageUrlContainingKey(request.getOriginalKey());
        if (targets.isEmpty()) {
            // 재시도/중복 호출 안정성을 위해 미매칭도 정상 ack 처리
            log.info("[Image/Callback] no matching todo_inputs. originalKey={}", request.getOriginalKey());
            return;
        }

        for (TodoInput input : targets) {
            List<String> replaced = input.getImageUrl().stream()
                    .map(key -> request.getOriginalKey().equals(key) ? request.getResizedKey() : key)
                    .toList();
            input.updateImageUrl(replaced);
        }
        // JPA dirty checking으로 커밋 시 반영
        log.info("[Image/Callback] updated todo_inputs={} originalKey={} resizedKey={}",
                targets.size(), request.getOriginalKey(), request.getResizedKey());
    }
}


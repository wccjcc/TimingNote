package com.timingnote.api.infra.client.ai;

import com.timingnote.api.infra.client.ai.dto.AiStructureRequest;
import com.timingnote.api.infra.client.ai.dto.AiStructureResponse;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.service.annotation.HttpExchange;
import org.springframework.web.service.annotation.PostExchange;
import reactor.core.publisher.Mono;

@HttpExchange("/internal")
public interface AiClient {

    @PostExchange("/structure")
    Mono<AiStructureResponse> structureMemo(@RequestBody AiStructureRequest request);
}

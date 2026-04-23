import uuid
import time
from typing import List, Protocol
from loguru import logger
from app.models.todo import StructureRequest, StructureResponse
from app.providers.base import LlmProvider
from app.config import settings

class StructureInterceptor(Protocol):
    """분석 전/후 처리 인터페이스. RAG, 웹검색, 텍스트 정규화 등에 활용."""
    def process(self, context: dict): ...

class StructureService:
    def __init__(self, llm_provider: LlmProvider):
        self._llm_provider = llm_provider
        self._pre_filters: List[StructureInterceptor] = []   # LLM 호출 전 처리 (정규화, GENERAL 사전 판별 등)
        self._post_filters: List[StructureInterceptor] = []  # LLM 호출 후 처리 (RAG 보완, 검증 등)

    async def structure_text(self, request: StructureRequest) -> StructureResponse:
        request_id = str(uuid.uuid4())
        start_time = time.time()

        with logger.contextualize(request_id=request_id):
            logger.info(f"분석 시작: {request.todoId}")

            analysis_output, meta_info = await self._llm_provider.extract_structure(
                request.originalText, request.userPlaceAliases
            )

            latency_ms = int((time.time() - start_time) * 1000)
            meta_info["latency_ms"] = latency_ms

            response = StructureResponse(
                todoId=request.todoId,
                **analysis_output.model_dump(),
                modelUsed=settings.AI_MAIN_MODEL,
                requestId=request_id,
                rawResultJson=meta_info,
            )

            logger.info(f"분석 완료 ({latency_ms}ms)")
            return response

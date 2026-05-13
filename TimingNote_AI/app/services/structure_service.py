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

            # user_places 별칭 매핑은 BE 책임으로 이관 — AI에는 텍스트만 전달.
            analysis_output, meta_info = await self._llm_provider.extract_structure(
                request.originalText
            )

            latency_ms = int((time.time() - start_time) * 1000)
            meta_info["latency_ms"] = latency_ms

            # timeHintText 후처리: rawExpression들을 join. LLM 출력에서 제거 → 출력 토큰 절감.
            # 복수 시간 표현은 ", "로 연결 (예: "내일 오전" + "모레 오후" → "내일 오전, 모레 오후").
            time_hint = ", ".join(
                tc.rawExpression for tc in analysis_output.timeConditions
                if tc.rawExpression
            ) or None

            response = StructureResponse(
                todoId=request.todoId,
                **analysis_output.model_dump(),
                timeHintText=time_hint,
                modelUsed=settings.AI_MAIN_MODEL,
                requestId=request_id,
                rawResultJson=meta_info,
            )

            # 분석 결과 요약 로그 — 필드별 추출 정확도·시간 매핑·hint join 결과를 한 줄로 검증.
            # originalText(메모 본문)는 민감도 높아 제외. category/placeText/timeConditions/hint만 노출.
            conditions_summary = ", ".join(
                f"{tc.conditionType.value}({tc.startTime or '-'}~{tc.endTime or '-'})"
                for tc in analysis_output.timeConditions
            ) or "none"
            logger.info(
                f"분석 완료 ({latency_ms}ms) | "
                f"category={analysis_output.category.value} | "
                f"placeText={analysis_output.placeText!r} | "
                f"conditions=[{conditions_summary}] | "
                f"hint={time_hint!r}"
            )
            return response

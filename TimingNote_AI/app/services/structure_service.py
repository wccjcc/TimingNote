import uuid
import time
from typing import List, Protocol, Optional
from loguru import logger
from app.models.todo import StructureRequest, StructureResponse, TodoType, TodoStructureOutput
from app.providers.base import LlmProvider
from app.config import settings

# 1. 확장을 위한 인터페이스 정의 (추후 필터 도입 대비)
class StructureInterceptor(Protocol):
    def process(self, context: dict):
        """데이터를 전처리하거나 보정하는 메서드"""
        ...

# 2. 핵심 서비스 로직 (모듈형 파이프라인)
class StructureService:
    def __init__(self, llm_provider: Optional[LlmProvider] = None):
        self._pre_filters: List[StructureInterceptor] = []
        self._post_filters: List[StructureInterceptor] = []
        self._llm_provider = llm_provider

    async def structure_text(self, request: StructureRequest) -> StructureResponse:
        """
        자연어 텍스트를 분석하여 구조화된 데이터로 변환합니다.
        """
        request_id = str(uuid.uuid4())
        start_time = time.time()
        
        with logger.contextualize(request_id=request_id):
            logger.info(f"분석 시작: {request.todoId}")

            if not self._llm_provider:
                raise ValueError("LLM Provider가 설정되지 않았습니다.")
            
            # 실제 LLM 분석 및 메트릭 수집
            analysis_output, meta_info = await self._llm_provider.extract_structure(request.originalText)

            # 지연 시간 측정 및 메타데이터 통합
            latency_ms = int((time.time() - start_time) * 1000)
            meta_info["latency_ms"] = latency_ms

            # 비즈니스 로직 처리 (TodoType 결정)
            todo_type = self._resolve_todo_type(analysis_output)

            # 최종 응답 조립 (분석에 용이한 최적화 구조)
            response = StructureResponse(
                todoId=request.todoId,
                **analysis_output.model_dump(),
                todo_type=todo_type,
                category_label=analysis_output.category.label,
                model_used=settings.AI_MAIN_MODEL, # 빠른 필터링용 태그
                request_id=request_id,
                raw_result_json=meta_info # 평탄화된 고품질 메타데이터
            )
            
            logger.info(f"분석 완료 ({latency_ms}ms)")
            return response

    def _resolve_todo_type(self, output: TodoStructureOutput) -> TodoType:
        """장소나 시간 맥락에 따른 유형 결정"""
        from app.models.todo import PlaceType
        if output.place_type != PlaceType.NONE or output.time_hint:
            return TodoType.STRUCTURED_TODO
        return TodoType.MEMO

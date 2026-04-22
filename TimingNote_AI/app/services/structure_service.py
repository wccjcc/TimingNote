import uuid
from typing import List, Protocol
from app.models.todo import StructureRequest, StructureResponse, TodoType, TodoStructureOutput

# 1. 확장을 위한 인터페이스 정의 (추후 필터 도입 대비)
class StructureInterceptor(Protocol):
    def process(self, context: dict):
        """데이터를 전처리하거나 보정하는 메서드"""
        ...

# 2. 핵심 서비스 로직 (모듈형 파이프라인)
class StructureService:
    def __init__(self):
        # 미래에 필터들을 등록할 리스트 (현재는 비어 있음)
        self._pre_filters: List[StructureInterceptor] = []
        self._post_filters: List[StructureInterceptor] = []

    async def structure_text(self, request: StructureRequest) -> StructureResponse:
        """
        자연어 텍스트를 분석하여 구조화된 데이터로 변환하는 핵심 워크플로우
        """
        # [Phase 1: Pre-filtering] - 미래의 비용 절감 필터가 들어갈 자리
        # 예: ㅋㅋㅋ 같은 무의미한 텍스트 차단 로직 등
        
        # [Phase 2: Core Processing] - 현재는 Mock 데이터를 반환, 추후 LLM 연동
        # (협의한 대로 '구조'를 먼저 잡기 위해 Mock 처리함)
        mock_output = self._get_mock_analysis(request.originalText)

        # [Phase 3: Business Logic & Post-filtering] - 정확도 보정
        # (예: 추출 실패 시 MEMO로 타입 전환 등)
        todo_type = self._resolve_todo_type(mock_output)

        # [Phase 4: Response Assembly] - 최종 응답 조립
        return StructureResponse(
            **mock_output.model_dump(),
            todo_type=todo_type,
            category_label=mock_output.category.label, # 한글 매핑 호출
            model_used="Mock-Engine-v1",
            request_id=str(uuid.uuid4())
        )

    def _get_mock_analysis(self, text: str) -> TodoStructureOutput:
        """분석 엔진 연동 전까지 사용할 임시 데이터 생성기"""
        from app.models.todo import TodoCategory, PlaceType
        
        # 실제로는 여기서 LLM이 호출될 예정
        return TodoStructureOutput(
            action=f"[{text}]에 대한 가상 분석 행동",
            category=TodoCategory.ETC,
            place_type=PlaceType.NONE,
            place_keyword=None,
            time_hint="상세 분석 필요"
        )

    def _resolve_todo_type(self, output: TodoStructureOutput) -> TodoType:
        """분석 결과에 따라 STRUCTURED_TODO 혹은 MEMO 여부 결정"""
        # 설계 철학: 장소나 시간 맥락이 전혀 없으면 단순 메모로 분류
        from app.models.todo import PlaceType
        
        if output.place_type == PlaceType.NONE and not output.time_hint:
            return TodoType.MEMO
        return TodoType.STRUCTURED_TODO

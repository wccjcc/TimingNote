from typing import Protocol, runtime_checkable
from app.models.todo import TodoStructureOutput

@runtime_checkable
class LlmProvider(Protocol):
    """LLM 연동을 위한 추상 인터페이스.

    AI는 텍스트 분석만 담당. user_places 별칭 매핑은 BE 책임으로 이관(2026-05-12 결정).
    """
    async def extract_structure(self, text: str) -> tuple[TodoStructureOutput, dict]:
        ...

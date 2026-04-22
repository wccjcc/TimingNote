from typing import Protocol, runtime_checkable
from app.models.todo import TodoStructureOutput

@runtime_checkable
class LlmProvider(Protocol):
    """LLM 연동을 위한 추상 인터페이스"""
    async def extract_structure(self, text: str) -> TodoStructureOutput:
        """자연어 텍스트에서 할 일 구조를 추출합니다."""
        ...

from typing import Protocol, runtime_checkable, List
from app.models.todo import TodoStructureOutput, UserPlaceAlias

@runtime_checkable
class LlmProvider(Protocol):
    """LLM 연동을 위한 추상 인터페이스"""
    async def extract_structure(self, text: str, aliases: List[UserPlaceAlias]) -> tuple[TodoStructureOutput, dict]:
        ...

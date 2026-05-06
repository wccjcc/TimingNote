from functools import lru_cache
from app.services.structure_service import StructureService
from app.providers.llm.openai_provider import OpenAiLlmProvider

@lru_cache()
def get_structure_service() -> StructureService:
    """
    StructureService를 싱글턴으로 관리하여 리소스 낭비를 방지합니다.
    추후 LLM 프로바이더나 임베딩 모델 로드 시 메모리 효율을 극대화합니다.
    """
    # LLM 프로바이더 주입
    llm_provider = OpenAiLlmProvider()
    return StructureService(llm_provider=llm_provider)

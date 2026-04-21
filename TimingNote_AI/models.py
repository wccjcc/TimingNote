# models.py
from pydantic import BaseModel
from typing import Optional

# 1. Spring Boot(또는 모바일)가 우리 서버로 보낼 요청 데이터 (Request)
class StructureRequest(BaseModel):
    todoId: int
    inputType: str
    originalText: str

# 2. 우리 서버가 최종적으로 응답할 데이터 (Response)
# (클로드가 조언했던 순수 LLM 출력 모델 구조를 일단 단순화했습니다)
class StructureResponse(BaseModel):
    action: str
    place_type: str
    place_keyword: Optional[str] = None # 값이 없을 수도 있음(None 허용)
    category: str
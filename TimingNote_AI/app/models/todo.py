from enum import Enum
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any

# 1. 행동 중심 카테고리 (사용자 경험의 핵심)
class TodoCategory(str, Enum):
    DINE = "DINE"             # 식사/카페
    ACQUIRE = "ACQUIRE"       # 쇼핑/수령
    HEALTH = "HEALTH"         # 병원/약국/운동
    SERVICE = "SERVICE"       # 은행/관공서/업무
    MAINTENANCE = "MAINTENANCE" # 세탁/주유/정비
    SOCIAL = "SOCIAL"         # 모임/방문/선물
    ETC = "ETC"               # 기타 메모

    @property
    def label(self) -> str:
        """사용자에게 보여줄 한글 명칭 매핑"""
        mapping = {
            TodoCategory.DINE: "식사/카페",
            TodoCategory.ACQUIRE: "쇼핑/수령",
            TodoCategory.HEALTH: "병원/약국/운동",
            TodoCategory.SERVICE: "은행/관공서/업무",
            TodoCategory.MAINTENANCE: "세탁/주유/정비",
            TodoCategory.SOCIAL: "모임/방문/선물",
            TodoCategory.ETC: "기타 메모",
        }
        return mapping.get(self, "기타 메모")

# 2. 분석 결과 타입 (비즈니스 로직 분기점)
class TodoType(str, Enum):
    STRUCTURED_TODO = "STRUCTURED_TODO" # 알림 등록 가능
    MEMO = "MEMO"                       # 단순 메모 (모호한 입력 시)

# 3. 장소 예측 정보
class PlaceType(str, Enum):
    SPECIFIC = "SPECIFIC" # 특정 장소 (예: 스타벅스 강남점)
    GENERIC = "GENERIC"   # 포괄적 장소 (예: 카페, 편의점)
    NONE = "NONE"

# --- Request/Response Schemas ---

class StructureRequest(BaseModel):
    todoId: int
    inputType: str = Field(..., description="TEXT or VOICE")
    originalText: str

class TodoStructureOutput(BaseModel):
    """AI 엔진(LLM)이 추출하는 순수 데이터 모델"""
    action: str = Field(..., description="수행할 핵심 행동")
    category: TodoCategory
    place_type: PlaceType
    place_keyword: Optional[str] = None
    time_hint: Optional[str] = None # 예: "저녁에", "내일 3시" 등 시간 맥락

class StructureResponse(TodoStructureOutput):
    """최종 API 응답 모델 (로그 및 통계 데이터 포함)"""
    todo_id: int = Field(..., alias="todoId") # BE 스펙에 맞춰 camelCase 지원
    todo_type: TodoType
    category_label: str # 사용자 노출용 한글 카테고리명
    model_used: str
    request_id: str # 로그 추적용 UUID
    raw_result_json: Dict[str, Any] # 토큰 사용량, 응답 시간 등 통계 데이터

    model_config = {
        "populate_by_name": True # alias와 field name 모두 사용 가능하게 설정
    }

from enum import Enum
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List

class TodoCategory(str, Enum):
    DINE = "DINE"
    ACQUIRE = "ACQUIRE"
    HEALTH = "HEALTH"
    SERVICE = "SERVICE"
    MAINTENANCE = "MAINTENANCE"
    SOCIAL = "SOCIAL"
    ETC = "ETC"

class ConditionType(str, Enum):
    DATETIME = "DATETIME"     # 날짜+시간 (내일 오후 3시)
    DATE = "DATE"             # 날짜만 (내일, 이번 주 금요일)
    DATE_RANGE = "DATE_RANGE" # 기간 (이번 주 중, ~까지)
    WEEK = "WEEK"             # 요일 반복 (매주 월요일)
    TIME_RANGE = "TIME_RANGE" # 시간대만 (저녁에, 오전 중)

class DayOfWeek(str, Enum):
    MON = "MON"
    TUE = "TUE"
    WED = "WED"
    THU = "THU"
    FRI = "FRI"
    SAT = "SAT"
    SUN = "SUN"

class TimeCondition(BaseModel):
    conditionType: ConditionType
    startDate: Optional[str] = None        # yyyy-MM-dd
    endDate: Optional[str] = None          # yyyy-MM-dd
    startTime: Optional[str] = None        # HH:mm
    endTime: Optional[str] = None          # HH:mm
    daysOfWeek: Optional[List[DayOfWeek]] = None  # BE에서 비트마스크로 변환
    rawExpression: Optional[str] = None    # 원문 시간 표현 보존

class StructureRequest(BaseModel):
    """AI 분석 요청.

    user_places 별칭 매핑은 BE 책임으로 이관(2026-05-12 결정) — AI는 텍스트만 받음.
    BE가 보내는 추가 필드(예: 과거 userPlaceAliases)는 pydantic 기본 동작(extra='ignore')으로 무시.
    """
    todoId: int
    inputType: str
    originalText: str

class TodoStructureOutput(BaseModel):
    """AI 분석 결과.

    placeType은 BE 책임으로 이관(2026-05-12 결정) — AI는 placeText 추출만 담당.
    BE가 검색 결과·user_places 매핑·일반명사 사전으로 자체 결정한다.
    """
    todoText: str
    category: TodoCategory
    placeText: Optional[str] = None
    timeHintText: Optional[str] = None
    timeConditions: List[TimeCondition] = Field(default_factory=list)

class StructureResponse(TodoStructureOutput):
    todoId: int
    modelUsed: str
    requestId: str
    rawResultJson: Dict[str, Any]

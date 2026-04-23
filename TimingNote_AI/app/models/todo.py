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

class PlaceType(str, Enum):
    SPECIFIC = "SPECIFIC"
    GENERIC = "GENERIC"
    ALIAS = "ALIAS"
    GENERAL = "GENERAL"

class ConditionType(str, Enum):
    DATETIME = "DATETIME"     # 날짜+시간 (내일 오후 3시)
    DATE = "DATE"             # 날짜만 (내일, 이번 주 금요일)
    DATE_RANGE = "DATE_RANGE" # 기간 (이번 주 중, ~까지)
    WEEKDAY = "WEEKDAY"       # 요일 반복 (매주 월요일)
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
    rawExpression: str                     # 원문 시간 표현 보존

class UserPlaceAlias(BaseModel):
    alias: str  # 사용자 등록 별칭 (예: "집", "회사")

class StructureRequest(BaseModel):
    todoId: int
    inputType: str
    originalText: str
    userPlaceAliases: List[UserPlaceAlias] = Field(default_factory=list)

class TodoStructureOutput(BaseModel):
    todoText: str
    category: TodoCategory
    placeType: PlaceType
    placeText: Optional[str] = None
    timeHintText: Optional[str] = None
    timeConditions: List[TimeCondition] = Field(default_factory=list)

class StructureResponse(TodoStructureOutput):
    todoId: int
    modelUsed: str
    requestId: str
    rawResultJson: Dict[str, Any]

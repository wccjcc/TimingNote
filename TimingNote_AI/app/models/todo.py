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
    """AI 분석 결과 (LLM 응답 스키마).

    AI는 원문을 재해석/재구성하지 않고 카테고리·장소·시간 정보만 추출한다.
    todoText는 사용자 원문이 그대로 보존되므로 AI 응답에 포함하지 않는다 (BE가 todo.content 사용).
    placeType도 BE 책임 (검색 결과·user_places·일반명사 사전으로 자체 결정).
    timeHintText는 LLM이 채우지 않고 AI 서버가 rawExpression들을 join해서 후처리로 생성한다
    (2026-05-13 결정 — rawExpression과의 중복 출력 토큰 절감).
    """
    category: TodoCategory
    placeText: Optional[str] = None
    timeConditions: List[TimeCondition] = Field(default_factory=list)

class StructureResponse(TodoStructureOutput):
    todoId: int
    # AI 서버가 timeConditions.rawExpression들을 join 해서 채움 (LLM 출력 X).
    timeHintText: Optional[str] = None
    modelUsed: str
    requestId: str
    rawResultJson: Dict[str, Any]

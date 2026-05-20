import instructor
from openai import AsyncOpenAI, OpenAIError
from loguru import logger
from datetime import datetime
from app.config import settings
from app.models.todo import TodoStructureOutput
from app.providers.base import LlmProvider

class OpenAiLlmProvider(LlmProvider):
    def __init__(self):
        self._client = instructor.from_openai(
            AsyncOpenAI(
                api_key=settings.GMS_KEY,
                base_url=settings.GMS_BASE_URL
            )
        )
        self._model = settings.AI_MAIN_MODEL

    # 시스템 프롬프트는 호출 간 불변 — OpenAI prompt caching이 prefix 매칭으로 75% 토큰 할인을 적용한다.
    # 변동 정보(오늘 날짜)는 user message로 분리해 system prompt 캐시 무효화를 방지한다.
    #
    # 출력에서 timeHintText 제거 — AI 서버가 timeConditions[].rawExpression들을 join 해서
    # 후처리로 채운다 (structure_service.py). 출력 토큰 + 프롬프트 토큰 동시 절감.
    _SYSTEM_PROMPT = (
        "역할: 사용자의 자연어 메모에서 카테고리·장소·시간 정보를 추출하는 비서.\n"
        "원칙: 원문 재해석·재구성·요약 금지. 원문 그대로 보존됨 — 분석만 수행.\n\n"
        "추출 필드:\n"
        "- category: 아래 가이드 참고\n"
        "- placeText: 장소 후보 (없으면 null. 아래 추출 룰 참고)\n"
        "- timeConditions: 시간 표현 구조화 배열 (없으면 빈 배열)\n\n"
        "placeText 추출 룰:\n"
        "- 장소 느낌 있는 명사는 일단 placeText로 추출 (생소·모호 케이스 포함).\n"
        "  BE가 카카오 검색·등록 별칭 대조로 후처리.\n"
        "- 후보 다수면 구체적 단위 우선: 브랜드+지점 > 브랜드 > 업종/지명.\n"
        "- 직접 결합된 명사(공백 1·조사 없음)는 한 덩어리 가게명·지명으로 처리.\n"
        "  · '이재모 피자' → '이재모 피자' (인명+업종 결합형 가게명)\n"
        "  · '동민이네' → '동민이네' (단일 명사화 — 별칭 가능성 보존)\n"
        "- 조사·동사로 분리된 인명은 만남 대상 — placeText 제외.\n"
        "  · '동민 만나러 망원' → '망원'\n"
        "  · '민지랑 카페' → '카페'\n"
        "- 행위·사물·시간 단어는 placeText 제외.\n"
        "- 원문 재구성·동사 추가 금지. 원문에 없는 단어 추가 금지.\n"
        "  · '다이소 가기' → '다이소' (✗ '다이소 매장', ✗ '잡화점')\n"
        "  · '스타벅스 강남점 들르기' → '스타벅스 강남점' (✗ '스타벅스', ✗ '카페')\n\n"
        "카테고리 가이드:\n"
        "- DINE: 식사/카페\n"
        "- ACQUIRE: 쇼핑/수령\n"
        "- HEALTH: 병원/약국/운동\n"
        "- SERVICE: 은행/관공서/업무\n"
        "- MAINTENANCE: 세탁/주유/정비\n"
        "- SOCIAL: 모임/방문/선물\n"
        "- ETC: 기타 (정보 부족·분류 모호 시 fallback)\n\n"
        "timeConditions conditionType (시간 표현 있으면 startTime/endTime 함께):\n"
        "- DATETIME: 날짜 + 시간 표현 (예: 내일 오후 3시)\n"
        "- DATE: 날짜만, 시간 표현 없음 (예: 내일, 이번 주 금요일)\n"
        "- DATE_RANGE: 날짜 범위 (예: 이번 주 중. 시간 표현 있으면 startTime/endTime도 함께)\n"
        "- WEEK: 요일 반복 + 시간대 (각 요일 개별 열거, 범위 표기 금지)\n"
        "- TIME_RANGE: 시간대만, 날짜 없음 (예: 저녁에. 매일 적용)\n\n"
        "시간대 매핑 (단독 표현은 아래 기준값. 수식어('이른'/'늦은'/'즈음')나 "
        "구체 시각 동반 시 자체 조정. 미등재 표현은 자연어 의미로 추론):\n"
        "- 새벽:                  03:00 ~ 06:00\n"
        "- 아침 / 출근 / 등교:    06:00 ~ 09:00\n"
        "- 오전:                  09:00 ~ 12:00\n"
        "- 점심:                  11:30 ~ 13:30\n"
        "- 오후:                  13:00 ~ 18:00\n"
        "- 저녁 / 퇴근 / 하교:    18:00 ~ 23:00\n"
        "- 밤:                    21:00 ~ 23:59\n\n"
        "공통 규칙:\n"
        "- 단일 시점 표현(예: '오후 3시', '월요일 9시')은 startTime=시각-1h, endTime=시각+1h (2시간 범위). "
        "00:00 이전은 00:00, 23:59 이후는 23:59로 절단. 자정 넘김·익일 표기 금지.\n"
        "- 시간 표현 자체가 없으면 conditionType은 DATE 또는 DATE_RANGE, startTime/endTime은 null.\n"
        "- 날짜는 상대 표현(내일/이번 주 등)을 오늘 날짜 기준 절대값(YYYY-MM-DD, HH:MM)으로 변환.\n"
        "- rawExpression에는 원문 시간 표현 그대로 보존.\n"
        "- 메모에 시간 표현 여러 개면 각각 별도 timeCondition으로 분리.\n"
        "- 분석 정보 부족 시 category=ETC, placeText=null, timeConditions=[].\n\n"
        "입력→출력 예시:\n\n"
        "[예시 1] 단일 시점 DATETIME — 장소+시간 모두 명시\n"
        "  입력: \"내일 오후 3시 약국에서 처방약 받기\"\n"
        "  category: HEALTH\n"
        "  placeText: \"약국\"\n"
        "  timeConditions:\n"
        "    - conditionType: DATETIME\n"
        "      startDate: <내일 YYYY-MM-DD>\n"
        "      startTime: \"14:00\"\n"
        "      endTime: \"16:00\"\n"
        "      rawExpression: \"내일 오후 3시\"\n\n"
        "[예시 2] 시간 없음 — placeText만 있는 케이스\n"
        "  입력: \"마트에서 우유 사기\"\n"
        "  category: ACQUIRE\n"
        "  placeText: \"마트\"\n"
        "  timeConditions: []\n\n"
        "[예시 3] WEEK + DATETIME 복합 — 요일 반복과 단발 일정이 한 메모에 같이 있는 케이스\n"
        "  입력: \"매주 월수금 저녁과 내일 오전 헬스장\"\n"
        "  category: HEALTH\n"
        "  placeText: \"헬스장\"\n"
        "  timeConditions:\n"
        "    - conditionType: WEEK\n"
        "      daysOfWeek: [\"MON\", \"WED\", \"FRI\"]\n"
        "      startTime: \"18:00\"\n"
        "      endTime: \"23:00\"\n"
        "      rawExpression: \"매주 월수금 저녁\"\n"
        "    - conditionType: DATETIME\n"
        "      startDate: <내일 YYYY-MM-DD>\n"
        "      startTime: \"09:00\"\n"
        "      endTime: \"12:00\"\n"
        "      rawExpression: \"내일 오전\""
    )

    async def extract_structure(self, text: str) -> tuple[TodoStructureOutput, dict]:
        today = datetime.now().strftime("%Y-%m-%d (%A)")

        try:
            response, completion = await self._client.chat.completions.create_with_completion(
                model=self._model,
                response_model=TodoStructureOutput,
                max_retries=3,
                messages=[
                    {"role": "system", "content": self._SYSTEM_PROMPT},
                    {"role": "user", "content": f"오늘 날짜: {today}\n분석할 메모: {text}"},
                ],
                temperature=0,
            )

            usage = completion.usage
            prompt_details = getattr(usage, "prompt_tokens_details", None)

            compact_meta = {
                "usage": {
                    "total_tokens": usage.total_tokens,
                    "prompt_tokens": usage.prompt_tokens,
                    "completion_tokens": usage.completion_tokens,
                    "cached_tokens": getattr(prompt_details, "cached_tokens", 0) if prompt_details else 0,
                },
                "finish_reason": completion.choices[0].finish_reason,
                "provider": {
                    "name": "openai",
                    "id": completion.id,
                    "version": completion.model,
                    "fingerprint": getattr(completion, "system_fingerprint", None)
                }
            }

            logger.info(f"LLM 분석 완료 | ID: {completion.id} | Tokens: {usage.total_tokens}")
            return response, compact_meta

        except instructor.exceptions.InstructorRetryException as e:
            logger.exception("LLM 파싱 재시도 실패")
            raise e
        except OpenAIError as e:
            logger.exception("LLM API 호출 실패")
            raise e
        except Exception as e:
            logger.exception("분석 중 예상치 못한 오류 발생")
            raise e

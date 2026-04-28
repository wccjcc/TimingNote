import instructor
from openai import AsyncOpenAI, OpenAIError
from loguru import logger
from datetime import datetime
from typing import List
from app.config import settings
from app.models.todo import TodoStructureOutput, UserPlaceAlias
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

    async def extract_structure(self, text: str, aliases: List[UserPlaceAlias]) -> tuple[TodoStructureOutput, dict]:
        today = datetime.now().strftime("%Y-%m-%d (%A)")

        alias_section = ""
        if aliases:
            alias_names = ", ".join(a.alias for a in aliases)
            alias_section = (
                f"\n사용자 등록 별칭 목록: {alias_names}\n"
                "메모에 위 별칭 중 하나가 장소로 사용된 경우 placeType=ALIAS, placeText=해당 별칭(원문 그대로)으로 설정하세요.\n"
            )

        try:
            response, completion = await self._client.chat.completions.create_with_completion(
                model=self._model,
                response_model=TodoStructureOutput,
                max_retries=3,
                messages=[
                    {
                        "role": "system",
                        "content": (
                            f"오늘 날짜: {today}\n\n"
                            "사용자의 자연어 메모를 분석하여 할 일(Todo)로 구조화하는 비서입니다.\n"
                            "다음 필드를 추출하세요:\n"
                            "- todoText: 수행할 핵심 행동 (간결하게)\n"
                            "- category: 아래 가이드 참고\n"
                            "- placeType: 아래 가이드 참고\n"
                            "- placeText: 장소명 또는 업종 (없으면 null)\n"
                            "- timeHintText: 시간 관련 원문 표현 (없으면 null, 예: '내일 오후 3시에', '매주 월요일')\n"
                            "- timeConditions: 시간 표현을 구조화한 배열 (없으면 빈 배열)\n\n"
                            "카테고리 가이드:\n"
                            "- DINE: 식사/카페\n"
                            "- ACQUIRE: 쇼핑/수령\n"
                            "- HEALTH: 병원/약국/운동\n"
                            "- SERVICE: 은행/관공서/업무\n"
                            "- MAINTENANCE: 세탁/주유/정비\n"
                            "- SOCIAL: 모임/방문/선물\n"
                            "- ETC: 기타\n\n"
                            "장소 유형 가이드:\n"
                            "- SPECIFIC: 특정 지점 명확 (예: 스타벅스 강남점, 홈플러스 서면점)\n"
                            "- GENERIC: 업종/브랜드만 (예: 편의점, 다이소, 약국)\n"
                            "- ALIAS: 사용자 등록 별칭 목록에 있는 장소\n"
                            "- GENERAL: 장소 맥락 없음\n\n"
                            + alias_section +
                            "timeConditions conditionType 가이드:\n"
                            "- DATETIME: 날짜+시간 모두 (예: 내일 오후 3시 → startDate + startTime 동시 설정)\n"
                            "- DATE: 날짜만 (예: 내일, 이번 주 금요일 → startDate만)\n"
                            "- DATE_RANGE: 기간 (예: 이번 주 중 → startDate~endDate)\n"
                            "- WEEK: 요일 반복 (예: 매주 월~금 → daysOfWeek: ['MON','TUE','WED','THU','FRI'], 범위 표기 금지, 반드시 각 요일 개별 열거)\n"
                            "- TIME_RANGE: 시간대만 (예: 저녁에 → startTime만)\n"
                            "날짜/시간은 상대 표현을 오늘 날짜 기준으로 절대값으로 변환하세요.\n"
                            "rawExpression에는 반드시 원문 시간 표현을 그대로 보존하세요."
                        )
                    },
                    {"role": "user", "content": f"분석할 메모: {text}"}
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

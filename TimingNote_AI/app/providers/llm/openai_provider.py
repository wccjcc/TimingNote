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

    async def extract_structure(self, text: str) -> tuple[TodoStructureOutput, dict]:
        today = datetime.now().strftime("%Y-%m-%d (%A)")

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
                            "- placeText: 장소명 또는 업종 (없으면 null. 장소 분류는 BE 책임이므로 추출만)\n"
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
                            "timeConditions conditionType 가이드 (모든 타입에서 시간 표현이 있으면 startTime/endTime을 함께 채웁니다):\n"
                            "- DATETIME: 날짜 + 시간 표현 (예: 내일 오후 3시 → startDate=내일, startTime=15:00, endTime=16:00)\n"
                            "- DATE: 날짜만, 시간 표현 없음 (예: 내일, 이번 주 금요일 → startDate만, startTime/endTime은 null)\n"
                            "- DATE_RANGE: 날짜 범위 (예: 이번 주 중 → startDate~endDate. 시간 표현 있으면 startTime/endTime도 함께)\n"
                            "- WEEK: 요일 반복 + 시간대 (예: 매주 월~금 저녁 → daysOfWeek=['MON','TUE','WED','THU','FRI'], startTime=18:00, endTime=22:00. 범위 표기 금지, 반드시 각 요일 개별 열거)\n"
                            "- TIME_RANGE: 시간대만, 날짜 없음 (예: 저녁에 → startTime=18:00, endTime=22:00. 매일 적용)\n\n"
                            "시간대 모호 표현은 아래 매핑으로 startTime/endTime을 자동 결정하세요:\n"
                            "- 새벽: 03:00 ~ 06:00\n"
                            "- 아침: 06:00 ~ 09:00\n"
                            "- 출근/등교 전: 07:00 ~ 09:00\n"
                            "- 오전: 09:00 ~ 12:00\n"
                            "- 점심: 11:30 ~ 13:30\n"
                            "- 오후: 13:00 ~ 18:00\n"
                            "- 저녁: 18:00 ~ 22:00\n"
                            "- 퇴근/하교 후: 18:00 ~ 23:00\n"
                            "- 밤: 21:00 ~ 23:59\n\n"
                            "단일 시점 표현(예: '내일 오후 3시', '월요일 9시')은 startTime을 그 시각의 1시간 전, endTime을 그 시각의 1시간 후로 설정하세요 (총 2시간 범위). 사용자가 정확한 시각보다 조금 일찍/늦게 장소를 지나가도 알림이 가도록 여유를 둡니다. 범위가 00:00 이전이면 00:00으로, 23:59 이후면 23:59로 잘라내세요(자정 넘김·익일 표기 금지).\n"
                            "시간 표현 자체가 메모에 없으면 conditionType은 DATE 또는 DATE_RANGE, startTime/endTime은 null입니다.\n"
                            "날짜/시간은 상대 표현을 오늘 날짜 기준으로 절대값(YYYY-MM-DD, HH:MM)으로 변환하세요.\n"
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

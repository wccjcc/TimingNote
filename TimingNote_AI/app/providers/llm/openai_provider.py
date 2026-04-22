import instructor
from openai import AsyncOpenAI, OpenAIError
from loguru import logger
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
        """
        OpenAI (GMS)를 통해 자연어 메모를 분석하고, 토큰 사용량을 포함한 메타데이터를 추출합니다.
        """
        try:
            response, completion = await self._client.chat.completions.create_with_completion(
                model=self._model,
                response_model=TodoStructureOutput,
                max_retries=3,
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "당신은 사용자의 자연어 메모를 분석하여 할 일(Todo)로 구조화하는 비서입니다.\n"
                            "메모에서 핵심 행동(action), 카테고리(category), 장소 유형(place_type), "
                            "장소 키워드(place_keyword), 시간 단서(time_hint)를 추출하세요.\n\n"
                            "카테고리 가이드:\n"
                            "- DINE: 식사/카페 (예: 점심 먹기, 커피 마시기)\n"
                            "- ACQUIRE: 쇼핑/수령 (예: 우유 사기, 택배 찾기)\n"
                            "- HEALTH: 병원/약국/운동 (예: 감기약 사기, 헬스장 가기)\n"
                            "- SERVICE: 은행/관공서/업무 (예: 등본 떼기, 입금하기)\n"
                            "- MAINTENANCE: 세탁/주유/정비 (예: 세탁물 맡기기, 기름 넣기)\n"
                            "- SOCIAL: 모임/방문/선물 (예: 친구 만나기, 선물 준비)\n"
                            "- ETC: 기타 메모 (명확한 할 일이 아닌 경우)\n\n"
                            "장소 유형 가이드:\n"
                            "- SPECIFIC: 특정 지점이 명확한 경우 (예: 스타벅스 강남점)\n"
                            "- GENERIC: 브랜드나 업종만 있는 경우 (예: 편의점, 다이소, 은행)\n"
                            "- NONE: 장소 맥락이 없는 경우"
                        )
                    },
                    {"role": "user", "content": f"분석할 메모: {text}"}
                ],
                temperature=0,
            )

            # 토큰 정보 및 메타데이터 정제
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

import os
from pathlib import Path
from dotenv import load_dotenv

# 프로젝트 루트 경로 계산
# 현재 파일: TimingNote_AI/app/config.py -> 3단계 위로 이동하면 루트
BASE_DIR = Path(__file__).resolve().parent.parent.parent
env_path = BASE_DIR / ".env"

# 루트 디렉토리의 .env 파일 로드 시도
if env_path.exists():
    load_dotenv(dotenv_path=env_path)
else:
    # 예외 상황 대비 (현재 디렉토리 로드)
    load_dotenv()

class Settings:
    # 내부 통신 인증 (BE → AI)
    AI_INTERNAL_SECRET: str = os.getenv("AI_INTERNAL_SECRET", "dev-secret")

    # GMS 공통 설정
    GMS_KEY: str = os.getenv("GMS_KEY", "")
    GMS_BASE_URL: str = os.getenv("GMS_BASE_URL", "https://gms.ssafy.io/gmsapi/api.openai.com/v1")
    
    # AI 전용 모델 설정 
    AI_MAIN_MODEL: str = os.getenv("AI_MAIN_MODEL", "gpt-4.1-mini")
    AI_STT_MODEL: str = os.getenv("AI_STT_MODEL", "gpt-4o-mini-transcribe")  # 음성 메모 분석용 (개발 예정)

# 설정을 싱글턴 인스턴스로 관리
settings = Settings()

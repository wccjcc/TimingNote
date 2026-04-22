from fastapi import FastAPI
from app.api import structure

# 1. FastAPI 애플리케이션 초기화 (2026 최신 안정화 버전)
app = FastAPI(
    title="TimingNote AI Server",
    description="자연어 할 일 구조화 및 STT 기능을 제공하는 핵심 AI 서버",
    version="0.1.0"
)

# 2. 헬스 체크 엔드포인트 (모니터링 필수)
@app.get("/health")
def health_check():
    """서버의 정상 작동 여부를 확인합니다."""
    return {"status": "ok", "message": "TimingNote AI Server is running"}

# 3. 라우터 등록 (기능별 모듈화)
app.include_router(structure.router)

# 4. 루트 접속 시 기본 안내 (선택사항)
@app.get("/")
def read_root():
    return {
        "project": "TimingNote AI",
        "docs": "/docs",
        "status": "ready"
    }

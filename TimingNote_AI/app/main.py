import os
import sys
import time
import uuid
from loguru import logger
from fastapi import FastAPI, Request
from app.api import structure

# 1. 로그 폴더 생성 (Git 무시 대상이므로 실행 시 생성 보장)
os.makedirs("logs", exist_ok=True)

# 2. 로거 설정 (지능형 포맷터 적용)
logger.remove()

def log_formatter(record):
    record_id = record["extra"].get("request_id", "SYSTEM")
    return f"<green>{{time:YYYY-MM-DD HH:mm:ss}}</green> | <level>{{level: <8}}</level> | <cyan>{record_id}</cyan> - <level>{{message}}</level>\n"

logger.add(sys.stdout, colorize=True, format=log_formatter)
logger.add(
    "logs/ai_server.log", 
    rotation="10 MB", 
    retention="10 days", 
    compression="zip",
    format=lambda r: f"{r['time']:YYYY-MM-DD HH:mm:ss} | {r['level']: <8} | {r['extra'].get('request_id', 'SYSTEM')} | {r['message']}\n"
)

# 3. FastAPI 애플리케이션 초기화
app = FastAPI(title="TimingNote AI Server", version="0.1.0")

# 4. HTTP 요청 로깅 미들웨어 (Traceability 강화)
@app.middleware("http")
async def log_requests(request: Request, call_next):
    request_id = str(uuid.uuid4())
    
    with logger.contextualize(request_id=request_id):
        start_time = time.time()
        logger.info(f"API 요청 수신: {request.method} {request.url.path}")
        
        try:
            response = await call_next(request)
            process_time = (time.time() - start_time) * 1000
            logger.info(f"API 응답 완료: HTTP {response.status_code} | 처리시간: {process_time:.2f}ms")
            response.headers["X-Request-ID"] = request_id
            return response
            
        except Exception as e:
            logger.exception(f"요청 처리 중 서버 오류 발생: {str(e)}")
            raise e

# 5. 라우터 등록
app.include_router(structure.router)

@app.get("/health")
def health_check():
    return {"status": "ok", "message": "TimingNote AI Server is running"}

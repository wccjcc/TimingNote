# main.py
from fastapi import FastAPI
from models import StructureRequest, StructureResponse

# FastAPI 앱 생성
app = FastAPI(title="타이밍노트 AI 서버")

# 가장 기본이 되는 Health Check API
@app.get("/health")
def health_check():
    return {"status": "ok", "message": "FastAPI 서버가 정상적으로 실행 중입니다!"}

# POST 방식의 구조화 API 생성
@app.post("/internal/structure", response_model=StructureResponse)
def structure_memo(request: StructureRequest):
    # 아직 AI는 연결하지 않았습니다!
    # 클라이언트가 보낸 originalText를 받아서 가짜 데이터(Mock)로 조립해 반환해 봅니다.

    return StructureResponse(
        action=f"[{request.originalText}] 분석 완료", # 입력받은 텍스트를 그대로 행동에 넣어봄
        place_type="NONE",
        place_keyword=None,
        category="테스트_카테고리"
    )
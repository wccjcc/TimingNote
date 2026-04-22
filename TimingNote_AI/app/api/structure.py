from fastapi import APIRouter, Depends, HTTPException, status
from app.models.todo import StructureRequest, StructureResponse
from app.dependencies import get_structure_service
from app.services.structure_service import StructureService

router = APIRouter(
    prefix="/internal",
    tags=["AI 구조화"],
    responses={422: {"description": "분석 불가능한 요청 데이터"}}
)

@router.post("/structure", response_model=StructureResponse, status_code=status.HTTP_200_OK)
async def structure_memo(
    request: StructureRequest,
    service: StructureService = Depends(get_structure_service)
):
    """
    사용자의 자연어 메모를 구조화된 데이터로 변환합니다.
    현재는 Mock 데이터를 반환하며, 추후 LLM 연동 시 실시간 분석을 수행합니다.
    """
    try:
        result = await service.structure_text(request)
        return result
    except Exception as e:
        # AI 분석 단계에서 발생하는 예기치 못한 에러 처리
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"AI 분석 중 오류가 발생했습니다: {str(e)}"
        )

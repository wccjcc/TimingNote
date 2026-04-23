from fastapi import APIRouter, Depends, HTTPException, Header, status
from app.models.todo import StructureRequest, StructureResponse
from app.dependencies import get_structure_service
from app.services.structure_service import StructureService
from app.config import settings

def verify_internal_secret(x_internal_secret: str = Header(...)):
    if x_internal_secret != settings.AI_INTERNAL_SECRET:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid internal secret")

router = APIRouter(
    prefix="/internal",
    tags=["AI 구조화"],
    dependencies=[Depends(verify_internal_secret)],
    responses={401: {"description": "인증 실패"}, 422: {"description": "분석 불가능한 요청 데이터"}}
)

@router.post("/structure", response_model=StructureResponse, status_code=status.HTTP_200_OK)
async def structure_memo(
    request: StructureRequest,
    service: StructureService = Depends(get_structure_service)
):
    try:
        return await service.structure_text(request)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"AI 분석 중 오류가 발생했습니다: {str(e)}"
        )

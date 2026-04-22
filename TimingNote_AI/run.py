import uvicorn

if __name__ == "__main__":
    # 개발 환경에서는 reload=True를 권장하며, 배포 시에는 uvicorn CLI를 사용합니다.
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)

# -*- coding: utf-8 -*-
"""FastAPI 入口。启动：python -m uvicorn app.main:app --host 0.0.0.0 --port 8000"""
import socket

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .llm import LLMError, analyze_reading
from .schemas import AnalyzeRequest, AnalysisResult

app = FastAPI(title="英语阅读精讲后端", version="0.1.0")

# 自用工具：允许手机直接跨域访问
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
async def health():
    return {"ok": True, "service": "reading-tutor-backend"}


@app.post("/api/analyze", response_model=AnalysisResult)
async def analyze(req: AnalyzeRequest):
    result, _ = await analyze_reading(req.article, req.questions or "", req.level or "auto")
    return result


@app.exception_handler(LLMError)
async def llm_error_handler(_request, exc: LLMError):
    from fastapi.responses import JSONResponse
    return JSONResponse(status_code=502, content={"detail": str(exc)})


def _lan_ip() -> str:
    """获取本机局域网 IP，方便手机连后端。"""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()


if __name__ == "__main__":
    import uvicorn
    from . import config

    ip = _lan_ip()
    print("=" * 60)
    print("后端已启动，手机和电脑连同一个 WiFi，在 App 设置页填：")
    print(f"  http://{ip}:{config.APP_PORT}")
    print("=" * 60)
    uvicorn.run(app, host="0.0.0.0", port=config.APP_PORT)

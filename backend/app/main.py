# -*- coding: utf-8 -*-
"""FastAPI 入口。启动：python -m uvicorn app.main:app --host 0.0.0.0 --port 8000"""
import socket

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from .dict_db import lookup_word
from .llm import LLMError, ask_tutor
from .pipeline import analyze_reading
from .schemas import (
    AnalyzeRequest,
    AnalysisResult,
    ChatAskRequest,
    ChatAskResponse,
)

app = FastAPI(title="英语阅读精讲后端", version="0.3.0")

# 自用工具：允许手机直接跨域访问
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    return {
        "message": "英语阅读精讲后端运行中",
        "docs": "/docs",
        "health": "/api/health",
        "analyze": "POST /api/analyze",
        "dict": "GET /api/dict/{word}",
        "chat": "POST /api/chat/ask",
    }


@app.get("/api/health")
async def health():
    return {"ok": True, "service": "reading-tutor-backend"}


@app.post("/api/analyze")
async def analyze(req: AnalyzeRequest):
    """分块分析：长文章也能完整覆盖。任何分析类错误统一返回 502 + 中文原因。"""
    try:
        result, _ = await analyze_reading(
            req.article, req.questions or "", req.level or "auto"
        )
        return result
    except LLMError as exc:
        return JSONResponse(status_code=502, content={"detail": str(exc)})
    except (ValidationError, ValueError, KeyError) as exc:
        return JSONResponse(
            status_code=502,
            content={"detail": f"模型返回的数据结构有误：{str(exc)[:200]}"},
        )
    except Exception as exc:  # noqa: BLE001 - 兜底，避免裸 500 让 App 无法提示
        return JSONResponse(
            status_code=502,
            content={"detail": f"分析服务异常：{str(exc)[:200]}"},
        )


@app.get("/api/dict/{word}")
async def dict_lookup(word: str):
    """云端全量词库查询：App 本地词库未命中时回退调用。"""
    row = await lookup_word(word)
    if not row:
        return JSONResponse(
            status_code=404,
            content={"found": False, "source": "cloud", "word": word},
        )
    return {"found": True, "source": "cloud", **row}


@app.post("/api/chat/ask", response_model=ChatAskResponse)
async def chat_ask(req: ChatAskRequest):
    """悬浮球随身问答（后端代理豆包，API Key 不下发到手机）。"""
    try:
        answer = await ask_tutor(req.question, req.history)
        return ChatAskResponse(answer=answer)
    except LLMError as exc:
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

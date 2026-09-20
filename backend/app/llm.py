# -*- coding: utf-8 -*-
"""调用豆包（火山方舟，OpenAI 兼容协议），并把返回解析成结构化结果。"""
import json
import re
from typing import Any, Dict, Tuple

import httpx

from . import config
from .prompts import SYSTEM_PROMPT, build_user_prompt
from .schemas import AnalysisResult


class LLMError(RuntimeError):
    pass


def _extract_json(text: str) -> Dict[str, Any]:
    """从模型输出里提取 JSON。兼容被 ```json 包裹、前后带解释文字的情况。"""
    text = text.strip()
    fence = re.search(r"```(?:json)?\s*(\{.*\})\s*```", text, re.S)
    if fence:
        text = fence.group(1)
    else:
        start, end = text.find("{"), text.rfind("}")
        if start != -1 and end != -1 and end > start:
            text = text[start:end + 1]
    return json.loads(text)


async def _chat(messages: list, temperature: float = 0.3) -> str:
    if not config.ARK_API_KEY or config.ARK_API_KEY.startswith("请把你的"):
        raise LLMError("尚未配置 ARK_API_KEY，请先复制 backend/.env.example 为 .env 并填入豆包 API Key")

    url = f"{config.ARK_BASE_URL}/chat/completions"
    headers = {
        "Authorization": f"Bearer {config.ARK_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": config.ARK_MODEL,
        "messages": messages,
        "temperature": temperature,
        # 要求方舟直接返回 JSON（豆包模型支持该参数）
        "response_format": {"type": "json_object"},
    }
    async with httpx.AsyncClient(timeout=90) as client:
        resp = await client.post(url, headers=headers, json=payload)
        if resp.status_code != 200:
            raise LLMError(f"豆包接口返回 {resp.status_code}：{resp.text[:300]}")
        data = resp.json()
    try:
        return data["choices"][0]["message"]["content"]
    except (KeyError, IndexError) as exc:
        raise LLMError(f"豆包返回结构异常：{json.dumps(data, ensure_ascii=False)[:300]}") from exc


async def analyze_reading(article: str, questions: str = "", level: str = "auto") -> Tuple[AnalysisResult, dict]:
    """返回 (结构化结果, 原始JSON，便于调试)。解析失败会带错误信息让模型自修一次。"""
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": build_user_prompt(article, questions, level)},
    ]

    raw_text = await _chat(messages)
    try:
        obj = _extract_json(raw_text)
    except (json.JSONDecodeError, ValueError) as first_err:
        # 第二次机会：把解析错误反馈给模型，要求只输出修正后的 JSON
        messages += [
            {"role": "assistant", "content": raw_text},
            {"role": "user", "content": f"你刚才的输出无法被 json.loads 解析，错误是：{first_err}。"
                                          "请只输出修正后的、严格合法的 JSON，不要任何其它文字。"},
        ]
        raw_text = await _chat(messages, temperature=0.1)
        obj = _extract_json(raw_text)  # 仍失败则向上抛异常

    # Pydantic 校验：字段缺失/类型不对会在这里报清楚
    result = AnalysisResult.model_validate(obj)
    return result, obj

# -*- coding: utf-8 -*-
"""调用豆包（火山方舟，OpenAI 兼容协议），并把返回解析成结构化数据。

分析类请求由 pipeline.py 编排：
- analyze_meta：全文主旨/题目/重点词汇
- analyze_sentence_chunk：分块逐句精讲
- ask_tutor：悬浮球随身问答
"""
import json
import re
from typing import Any, Dict, List, Optional

import httpx

from . import config
from .prompts import (
    META_SYSTEM_PROMPT,
    SENTENCE_SYSTEM_PROMPT,
    build_meta_prompt,
    build_sentence_prompt,
)


class LLMError(RuntimeError):
    pass


# 悬浮球随身问答的人设
TUTOR_SYSTEM_PROMPT = """你是一名耐心、专业的英语学习私教，名叫豆包。
学生可以随时向你提问：单词、词组、语法、长难句、翻译、写作、考试备考等英语问题，也可以问一般的学习方法问题。
要求：
1. 用简体中文回答，语言通俗易懂，多举简单的英文例句并附中文。
2. 结构清晰：先直接给结论，再分点说明，重点内容用“注意：”等字样提示。
3. 回答控制在 300 字以内，问题复杂时再适当展开，不要啰嗦。
4. 不确定的事实不要编造。"""


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


async def _chat(
    messages: list,
    temperature: float = 0.3,
    json_mode: bool = True,
    max_tokens: Optional[int] = None,
) -> str:
    if not config.ARK_API_KEY or config.ARK_API_KEY.startswith("请把你的"):
        raise LLMError("尚未配置 ARK_API_KEY，请先在 backend/.env 填入豆包 API Key")

    url = f"{config.ARK_BASE_URL}/chat/completions"
    headers = {
        "Authorization": f"Bearer {config.ARK_API_KEY}",
        "Content-Type": "application/json",
    }
    payload: Dict[str, Any] = {
        "model": config.ARK_MODEL,
        "messages": messages,
        "temperature": temperature,
    }
    if max_tokens:
        payload["max_tokens"] = max_tokens
    if json_mode:
        # 要求方舟直接返回 JSON（豆包模型支持该参数）
        payload["response_format"] = {"type": "json_object"}
    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(url, headers=headers, json=payload)
        if resp.status_code != 200:
            raise LLMError(f"豆包接口返回 {resp.status_code}：{resp.text[:300]}")
        data = resp.json()
    # 检查是否因输出长度被截断（finish_reason=length）
    try:
        choice = data["choices"][0]
        content = choice["message"]["content"]
        if choice.get("finish_reason") == "length":
            raise LLMError("模型输出达到 token 上限被截断，请调小分块或增大 MAX_TOKENS")
        return content
    except (KeyError, IndexError) as exc:
        raise LLMError(
            f"豆包返回结构异常：{json.dumps(data, ensure_ascii=False)[:300]}"
        ) from exc


async def _json_chat(
    messages: list,
    temperature: float = 0.3,
    max_tokens: Optional[int] = None,
) -> Dict[str, Any]:
    """请求 JSON 并解析；解析失败带错误让模型自修一次。"""
    raw_text = await _chat(messages, temperature, json_mode=True, max_tokens=max_tokens)
    try:
        return _extract_json(raw_text)
    except (json.JSONDecodeError, ValueError) as first_err:
        messages += [
            {"role": "assistant", "content": raw_text},
            {"role": "user",
             "content": f"你刚才的输出无法被 json.loads 解析，错误是：{first_err}。"
                        "请只输出修正后的、严格合法的 JSON，不要任何其它文字。"},
        ]
        raw_text = await _chat(
            messages, temperature=0.1, json_mode=True, max_tokens=max_tokens
        )
        return _extract_json(raw_text)


async def analyze_meta(
    article: str, questions: str = "", level: str = "auto"
) -> Dict[str, Any]:
    """全文主旨、题目解析、重点词汇（输出较小，一次请求）。"""
    messages = [
        {"role": "system", "content": META_SYSTEM_PROMPT},
        {"role": "user", "content": build_meta_prompt(article, questions, level)},
    ]
    return await _json_chat(messages, temperature=0.3, max_tokens=config.MAX_TOKENS)


async def analyze_sentence_chunk(
    chunk: List[str], level: str = "auto"
) -> List[Dict[str, Any]]:
    """单个分块的逐句精讲，返回句子原始字典列表。"""
    messages = [
        {"role": "system", "content": SENTENCE_SYSTEM_PROMPT},
        {"role": "user", "content": build_sentence_prompt(chunk, level)},
    ]
    obj = await _json_chat(messages, temperature=0.3, max_tokens=config.MAX_TOKENS)
    sentences = obj.get("sentences")
    if not isinstance(sentences, list):
        raise LLMError("分块返回缺少 sentences 数组")
    # 归一化：正常应为对象；模型偶尔返回字符串（仅原句），包成 {"en": s}
    normalized: List[Dict[str, Any]] = []
    for s in sentences:
        if isinstance(s, dict):
            normalized.append(dict(s))
        elif isinstance(s, str) and s.strip():
            normalized.append({"en": s})
    return normalized


async def ask_tutor(
    question: str, history: Optional[List] = None
) -> str:
    """悬浮球随身问答：带上最近几轮上下文，普通文本回答（非 JSON）。"""
    messages: List[dict] = [{"role": "system", "content": TUTOR_SYSTEM_PROMPT}]
    if history:
        for m in history[-10:]:
            if isinstance(m, dict):
                role, content = m.get("role"), m.get("content")
            else:
                role, content = getattr(m, "role", None), getattr(m, "content", None)
            if role in ("user", "assistant") and content and str(content).strip():
                messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": question})
    return await _chat(messages, temperature=0.6, json_mode=False, max_tokens=2048)

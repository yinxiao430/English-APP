# -*- coding: utf-8 -*-
"""分块分析编排：保证长文章也能完整逐句精讲。

流程：
1. 把文章按句切分，再按 SENTENCE_CHUNK_SIZE 分组；
2. meta（主旨/题目/词汇）与各句子分块并发请求豆包；
3. 每个分块失败或句子数不足时自动重试一次；
4. 合并所有句子并重新连续编号，Pydantic 校验后返回。
"""
import asyncio
import re
from typing import Any, Dict, List, Tuple

from . import config
from .llm import LLMError, analyze_meta, analyze_sentence_chunk
from .schemas import AnalysisResult


def split_sentences(article: str) -> List[str]:
    """把 OCR 文本切成句子。先合并多余空白，再按句末标点切分。"""
    text = re.sub(r"\s+", " ", article).strip()
    if not text:
        return []
    # .!? 后接空格、且空格后是大写字母/数字/引号/括号时切分
    parts = re.split(r"(?<=[.!?])\s+(?=[A-Z0-9\"'(])", text)
    return [p.strip() for p in parts if p.strip()]


def _make_chunks(sentences: List[str]) -> List[List[str]]:
    size = max(1, config.SENTENCE_CHUNK_SIZE)
    return [sentences[i:i + size] for i in range(0, len(sentences), size)]


async def _run_chunk(chunk: List[str], level: str) -> List[Dict[str, Any]]:
    """请求一个分块；句子数不足或异常时重试一次，取句子更多的结果。"""
    try:
        first = await analyze_sentence_chunk(chunk, level)
    except LLMError:
        first = None

    expected = len(chunk)
    if first is not None and len(first) >= expected:
        return first

    # 重试一次
    try:
        second = await analyze_sentence_chunk(chunk, level)
    except LLMError:
        second = None

    if first is None and second is None:
        raise LLMError(f"有 {expected} 个句子的分块两次分析均失败，请稍后重试")
    if second is None:
        return first  # type: ignore[return-value]
    if first is None:
        return second
    return second if len(second) > len(first) else first


async def analyze_reading(
    article: str, questions: str = "", level: str = "auto"
) -> Tuple[AnalysisResult, Dict[str, Any]]:
    """返回 (结构化结果, 合并后的原始字典)。"""
    sentences = split_sentences(article)
    if not sentences:
        raise LLMError("文章正文为空，无法分析")
    chunks = _make_chunks(sentences)

    # meta 与所有分块并发（LLM 在云端，并发不占本机资源）
    meta_future = asyncio.ensure_future(
        analyze_meta(article, questions or "", level)
    )
    chunk_futures = [
        asyncio.ensure_future(_run_chunk(chunk, level)) for chunk in chunks
    ]
    all_results = await asyncio.gather(meta_future, *chunk_futures)

    meta = all_results[0]
    sentence_dicts: List[Dict[str, Any]] = []
    for r in all_results[1:]:
        sentence_dicts.extend(r)

    # 合并后重新连续编号
    for i, s in enumerate(sentence_dicts, start=1):
        s["seq"] = i

    merged = {
        "summary": meta.get("summary", "") if isinstance(meta, dict) else "",
        "sentences": sentence_dicts,
        "questions": meta.get("questions", []) if isinstance(meta, dict) else [],
        "key_vocab": meta.get("key_vocab", []) if isinstance(meta, dict) else [],
    }
    result = AnalysisResult.model_validate(merged)
    return result, merged

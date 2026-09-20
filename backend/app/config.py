# -*- coding: utf-8 -*-
"""读取 .env 配置。"""
import os
from dotenv import load_dotenv

load_dotenv()

ARK_API_KEY = os.getenv("ARK_API_KEY", "").strip()
ARK_MODEL = os.getenv("ARK_MODEL", "doubao-1-5-pro-32k-250115").strip()
ARK_BASE_URL = os.getenv("ARK_BASE_URL", "https://ark.cn-beijing.volces.com/api/v3").strip().rstrip("/")
APP_PORT = int(os.getenv("APP_PORT", "8000"))

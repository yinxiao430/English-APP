@echo off
chcp 65001 >nul
set PYTHONUTF8=1
cd /d %~dp0

if not exist .venv (
    echo [1/3] 首次运行，正在创建虚拟环境...
    py -3.9 -m venv .venv
)
call .venv\Scripts\activate.bat

echo [2/3] 检查依赖...
python -m pip install -q -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

if not exist .env (
    echo [3/3] 未发现 .env，正在从模板创建，请填入豆包 API Key 后重新运行本脚本...
    copy .env.example .env >nul
    notepad .env
    pause
    exit /b 0
)

echo [3/3] 启动后端服务...
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
pause

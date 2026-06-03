@echo off
chcp 65001 >nul
echo ========================================
echo   MLS 开发环境一键启动
echo ========================================

REM 1. 查本机 IP
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4.*192\.168"') do set IP=%%a
set IP=%IP: =%
echo.
echo   真机 baseUrl: http://%IP%:8000
echo   辞典服务:     http://%IP%:8001
echo   Swagger:      http://%IP%:8000/docs
echo   模拟器用:     http://10.0.2.2:8000

REM 2. 确认 MongoDB 运行
echo.
echo 检查 MongoDB...
sc query MongoDB | findstr "RUNNING" >nul
if errorlevel 1 (
    echo [WARN] MongoDB 未运行, 尝试启动...
    net start MongoDB
    if errorlevel 1 echo [FAIL] 请手动启动 MongoDB 后再运行本脚本 && pause && exit /b 1
)
echo [OK] MongoDB 已运行

REM 3. 启动三服务
echo.
echo 启动 MLS backend (8000)...
start "MLS Backend" cmd /k "cd /d C:\projects\mls\backend && venv\Scripts\activate && python -c "from database import db; print('[V3] using db:', db.name); print()" && uvicorn main:app --reload --host 0.0.0.0 --port 8000"

echo 启动辞典 backend (8001)...
start "Dictionary Backend" cmd /k "cd /d C:\projects\mls\property-dictionary\backend && venv\Scripts\activate && uvicorn main:app --reload --host 0.0.0.0 --port 8001"

echo 启动 Flutter 前端...
start "Flutter App" cmd /k "cd /d C:\projects\mls\app\mls_app && flutter run"

echo.
echo ========================================
echo   三窗口已启动
echo   关闭本窗口不影响服务, 按任意键退出
echo ========================================
pause >nul

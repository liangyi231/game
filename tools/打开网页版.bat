@echo off
chcp 65001 >nul
cd /d "%~dp0..\dist\web"
if not exist "index.html" (
  echo 找不到 dist\web\index.html，请先导出网页版。
  pause
  exit /b 1
)
echo 正在启动本地服务（端口 8080）...
start "大肥鱼传说-网页版服务" /min python -m http.server 8080
timeout /t 2 >nul
start "" "http://127.0.0.1:8080/index.html"
echo 已尝试打开浏览器。手机在同一 Wi-Fi 下访问 http://<本机IP>:8080

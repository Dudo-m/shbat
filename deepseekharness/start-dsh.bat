@echo off
REM Start DeepSeek Harness web server, auto open browser when port is ready.
REM First run will auto-install @deepseek-ai/dsh (npx -y).

echo Starting DeepSeek Harness server...
echo First run may download and install, please wait...

REM Launch server in a new window
start /min "DSH Web Server" cmd /k "npx -y @deepseek-ai/dsh web"

REM Poll 127.0.0.1:3080 until connectable (up to 300s for first install)
set /a tries=0
:wait
if %tries% geq 300 goto open
powershell -NoProfile -Command "try{(New-Object System.Net.Sockets.TcpClient('127.0.0.1',3080)).Close(); exit 0}catch{exit 1}" >nul 2>&1
if errorlevel 1 (
    set /a tries+=1
    timeout /t 1 >nul
    goto wait
)

:open
echo Server ready, opening browser http://127.0.0.1:3080
start http://127.0.0.1:3080
exit

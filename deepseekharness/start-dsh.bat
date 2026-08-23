@echo off
REM Start DeepSeek Harness web server.
REM dsh web opens the browser automatically once the server is ready.
REM First run will auto-install @deepseek-ai/dsh (npx -y).

echo Starting DeepSeek Harness server...
echo First run may download and install, please wait...

start /min "DSH Web Server" cmd /k "npx -y @deepseek-ai/dsh web"
exit

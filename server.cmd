@echo off
cd /d "%~dp0"
echo.
echo Sunucu baslatiliyor: http://localhost:8000
echo Durdurmak icin: Ctrl + C
echo.
python -m http.server 8000
pause

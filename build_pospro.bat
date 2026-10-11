@echo off
setlocal

set "STAMP=%DATE%_%TIME%"
set "STAMP=%STAMP:/=-%"
set "STAMP=%STAMP::=-%"
set "STAMP=%STAMP:.=-%"
set "STAMP=%STAMP: =_%"

set "DISTPATH=dist\pospro_%STAMP%"
set "WORKPATH=build\pospro_%STAMP%"

pyinstaller -y --clean --distpath "%DISTPATH%" --workpath "%WORKPATH%" pospro.spec
if errorlevel 1 exit /b %errorlevel%

echo.
echo Ejecutable generado en:
echo %DISTPATH%\pospro\pospro.exe

@echo off
setlocal

rem Compila e instala Effica en un solo paso. El script solicita elevacion UAC.
set "SCRIPT=%~dp0install_pospro.ps1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
    echo.
    echo La instalacion termino con errores. Codigo: %EXITCODE%
    if exist "%~dp0install_pospro.log" (
        echo.
        echo Motivo:
        type "%~dp0install_pospro.log"
    )
) else (
    echo.
    echo La instalacion termino correctamente.
)

pause
exit /b %EXITCODE%

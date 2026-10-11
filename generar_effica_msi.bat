@echo off
setlocal

rem Compila Effica y genera el instalador MSI.
set "SCRIPT=%~dp0build_effica_msi.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
    echo.
    echo No se pudo generar el MSI. Codigo: %EXITCODE%
) else (
    echo.
    echo MSI generado correctamente en dist\Effica.msi
)

pause
exit /b %EXITCODE%

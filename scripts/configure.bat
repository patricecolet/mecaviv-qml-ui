@echo off
REM Script helper pour configurer le projet avec CMake (Windows)
REM Usage: configure.bat [preset]
REM Presets: default, release, wasm, windows

setlocal

set PRESET=%1
if "%PRESET%"=="" set PRESET=default

echo ================================================
echo Configuration CMake - Preset: %PRESET%
echo ================================================
echo.

REM Vérifier que CMake est installé
where cmake >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo CMake n'est pas installé
    echo Installation: https://cmake.org/download/
    exit /b 1
)

REM Configuration
echo Configuration du projet...
cmake --preset=%PRESET%

echo.
echo ================================================
echo Configuration terminée !
echo ================================================
echo.
echo Pour builder :
echo   cmake --build build
echo.
echo Ou avec le preset :
echo   cmake --build --preset=%PRESET%
echo.

endlocal


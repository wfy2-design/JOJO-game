@echo off
setlocal
cd /d "%~dp0game_code"

if not exist "build\battle.exe" (
    echo Game executable not found: game_code\build\battle.exe
    echo Run game_code\run.bat once to build the game.
    pause
    exit /b 1
)

start "" "build\battle.exe"
endlocal

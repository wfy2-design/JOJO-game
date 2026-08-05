@echo off
rem Turn-based battle launcher (ASCII only)
cd /d %~dp0

echo === Compiling ===
if not exist build mkdir build
mingw32-make all
if errorlevel 1 (
    echo Build failed. Please make sure D:\mingw64\bin is in PATH.
    pause
    exit /b 1
)

echo === Copying runtime DLLs ===
copy /Y third_party\SFML-2.5.1\bin\*.dll build\ >nul
rem Use PowerShell Copy-Item (Git mingw64 DLLs are hardlinks, cmd copy fails on them)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item 'D:\git\Git\mingw64\bin\libgcc_s_seh-1.dll','D:\git\Git\mingw64\bin\libstdc++-6.dll','D:\mingw64\bin\libwinpthread-1.dll' 'build\' -Force"
if not exist build\libstdc++-6.dll (
    echo ERROR: failed to copy runtime DLLs.
    pause
    exit /b 1
)

echo === Launching game ===
build\battle.exe

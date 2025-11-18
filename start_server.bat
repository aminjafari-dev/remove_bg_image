@echo off
REM Quick start script for Windows
REM This script checks dependencies and starts the Flask server

echo 🚀 Starting Background Removal Server...
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python is not installed. Please install Python 3.8 or higher.
    pause
    exit /b 1
)

REM Check if requirements are installed
echo 📦 Checking dependencies...
python -c "import flask" >nul 2>&1
if errorlevel 1 (
    echo ⚠️  Flask not found. Installing dependencies...
    pip install -r requirements.txt
)

python -c "import rembg" >nul 2>&1
if errorlevel 1 (
    echo ⚠️  rembg not found. Installing dependencies...
    pip install -r requirements.txt
)

echo ✅ Dependencies checked
echo.
echo 🌐 Starting server...
echo.

REM Start the server
python server.py

pause


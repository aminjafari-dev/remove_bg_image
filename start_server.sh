#!/bin/bash

# Quick start script for the background removal server
# This script checks dependencies and starts the Flask server

echo "🚀 Starting Background Removal Server..."
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8 or higher."
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is not installed. Please install pip."
    exit 1
fi

# Check if requirements are installed
echo "📦 Checking dependencies..."
if ! python3 -c "import flask" 2>/dev/null; then
    echo "⚠️  Flask not found. Installing dependencies..."
    pip3 install -r requirements.txt
fi

if ! python3 -c "import rembg" 2>/dev/null; then
    echo "⚠️  rembg not found. Installing dependencies..."
    pip3 install -r requirements.txt
fi

echo "✅ Dependencies checked"
echo ""
echo "🌐 Starting server..."
echo ""

# Start the server
python3 server.py


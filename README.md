# Background Removal Image Processing

A full-stack solution for removing backgrounds from images, consisting of a Python Flask server and a Flutter mobile application.

## Project Structure

```
remove_bg_image/
├── server.py                 # Flask server for background removal
├── requirements.txt          # Python dependencies
├── start_server.sh           # Quick start script (macOS/Linux)
├── start_server.bat          # Quick start script (Windows)
├── SERVER_SETUP.md          # Detailed server setup guide
├── image_classification.py  # Original classification script
├── remove_bg.py             # Simple background removal script
├── processed_images/        # Output directory for processed images
└── remove_bg_test/          # Flutter application
    └── lib/
        ├── main.dart        # Main Flutter app
        └── services/
            └── background_removal_service.dart  # API service
```

## Quick Start

### 1. Start the Python Server

**macOS/Linux:**
```bash
./start_server.sh
```

**Windows:**
```bash
start_server.bat
```

**Manual:**
```bash
pip install -r requirements.txt
python server.py
```

The server will start on `http://localhost:5000`

### 2. Configure Flutter App

The Flutter app is pre-configured for Android emulator (`http://10.0.2.2:5000`).

For iOS Simulator or physical devices, update the server URL in:
```
remove_bg_test/lib/services/background_removal_service.dart
```

See [SERVER_SETUP.md](SERVER_SETUP.md) for detailed configuration instructions.

### 3. Run Flutter App

```bash
cd remove_bg_test
flutter pub get
flutter run
```

## Features

- ✅ Remove background from images using AI (rembg library)
- ✅ RESTful API with Flask
- ✅ Flutter mobile app with image picker
- ✅ Server health check endpoint
- ✅ Support for file upload and base64 encoding
- ✅ Cross-platform (Android, iOS, Web)

## API Endpoints

- `GET /health` - Check server status
- `POST /remove-background` - Remove background (multipart/form-data)
- `POST /remove-background-base64` - Remove background (JSON with base64)

## Technologies

- **Backend**: Python, Flask, rembg, Pillow
- **Frontend**: Flutter, Dart
- **Image Processing**: rembg (AI-powered background removal)

## Requirements

- Python 3.8+
- Flutter SDK
- pip (Python package manager)

## Documentation

- [Server Setup Guide](SERVER_SETUP.md) - Detailed server configuration and troubleshooting

## License

This project is for educational purposes.

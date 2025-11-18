# Background Removal Server Setup Guide

This guide will help you set up and run the Python Flask server for background removal.

## Prerequisites

1. Python 3.8 or higher installed on your system
2. pip (Python package manager)

## Installation Steps

### 1. Install Python Dependencies

Open a terminal in the project root directory and run:

```bash
pip install -r requirements.txt
```

This will install:
- Flask (web framework)
- flask-cors (CORS support for Flutter app)
- rembg (background removal library)
- Pillow (image processing)
- numpy (numerical operations)

### 2. Start the Server

Run the server using:

```bash
python server.py
```

You should see output like:
```
🚀 Starting Background Removal Server...
📍 Server will be available at: http://localhost:5000
📡 Health check: http://localhost:5000/health
🖼️  Remove background: http://localhost:5000/remove-background
```

The server will start on `http://localhost:5000` by default.

## Server Endpoints

### Health Check
- **URL**: `http://localhost:5000/health`
- **Method**: GET
- **Description**: Check if the server is running
- **Response**: `{"status": "ok", "message": "Background removal server is running"}`

### Remove Background (File Upload)
- **URL**: `http://localhost:5000/remove-background`
- **Method**: POST
- **Content-Type**: `multipart/form-data`
- **Field**: `image` (file)
- **Response**: PNG image with background removed

### Remove Background (Base64)
- **URL**: `http://localhost:5000/remove-background-base64`
- **Method**: POST
- **Content-Type**: `application/json`
- **Body**: `{"image": "data:image/jpeg;base64,..."}`
- **Response**: `{"success": true, "image": "data:image/png;base64,..."}`

## Flutter App Configuration

### For Android Emulator
The Flutter app is configured to use `http://10.0.2.2:5000` by default, which is the special IP address that Android emulator uses to access the host machine's localhost.

### For iOS Simulator
If you're using iOS Simulator, you need to update the server URL in:
```
remove_bg_test/lib/services/background_removal_service.dart
```

Change the `baseUrl` to:
```dart
static const String baseUrl = 'http://localhost:5000';
```

### For Physical Device
If you're testing on a physical device, you need to:

1. Find your computer's IP address:
   - **macOS/Linux**: Run `ifconfig` or `ip addr show`
   - **Windows**: Run `ipconfig`
   - Look for your local network IP (usually starts with 192.168.x.x or 10.0.x.x)

2. Update the server URL in `background_removal_service.dart`:
   ```dart
   static const String baseUrl = 'http://YOUR_IP_ADDRESS:5000';
   ```

3. Make sure your device and computer are on the same Wi-Fi network

4. Start the server with:
   ```bash
   python server.py
   ```
   (The server already binds to `0.0.0.0`, so it will accept connections from your network)

## Testing the Server

You can test the server using curl:

```bash
# Health check
curl http://localhost:5000/health

# Remove background (replace with your image path)
curl -X POST http://localhost:5000/remove-background \
     -F "image=@path/to/your/image.jpg" \
     --output processed_image.png
```

## Troubleshooting

### Server won't start
- Make sure port 5000 is not already in use
- Check that all dependencies are installed: `pip list`
- Verify Python version: `python --version` (should be 3.8+)

### Flutter app can't connect
- Verify server is running: Open `http://localhost:5000/health` in a browser
- Check the server URL in `background_removal_service.dart` matches your setup
- For physical devices, ensure both devices are on the same network
- Check firewall settings - port 5000 might be blocked

### Background removal fails
- Check server logs for error messages
- Verify the image file is valid
- Make sure rembg library is properly installed: `pip show rembg`

## Notes

- The server runs in debug mode by default (useful for development)
- Processed images are saved in the `processed_images/` directory
- Uploaded images are temporarily stored in the `uploads/` directory
- The first time you use `rembg`, it will download the AI model (this may take a few minutes)


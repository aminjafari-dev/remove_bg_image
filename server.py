"""
Flask server for removing background from images.
This server accepts image uploads and returns the processed image with background removed.
"""
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from rembg import remove
from PIL import Image
import io
import os
from datetime import datetime

from typing import Optional

from user_service import UserService

app = Flask(__name__)
# Enable CORS for Flutter app
CORS(app)

# Instantiate user service for authentication and storage
user_service = UserService()

# Configuration
UPLOAD_FOLDER = "uploads"
OUTPUT_FOLDER = "processed_images"

# Create necessary directories
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)


def _extract_token(auth_header: Optional[str]) -> Optional[str]:
    """
    Helper to parse `Authorization: Bearer <token>` values.

    Example:
        >>> _extract_token("Bearer 123")
        "123"
    """
    if not auth_header:
        return None
    parts = auth_header.split(" ")
    if len(parts) == 2 and parts[0].lower() == "bearer":
        return parts[1]
    return None


@app.route('/health', methods=['GET'])
def health_check():
    """
    Health check endpoint to verify server is running.
    Returns: JSON response with status
    """
    return jsonify({"status": "ok", "message": "Background removal server is running"})


@app.route('/auth/register', methods=['POST'])
def register_user():
    """
    Register a user by sending JSON with username/password.

    Example:
        curl -X POST http://localhost:5045/auth/register \
            -H "Content-Type: application/json" \
            -d '{"username": "demo", "password": "secret123"}'
    """
    data = request.get_json(force=True, silent=True) or {}

    username = data.get("username", "").strip()
    password = data.get("password", "")

    if not username or not password:
        return jsonify({"success": False, "message": "Username and password are required."}), 400

    created = user_service.register_user(username=username, password=password)
    if not created:
        return jsonify({"success": False, "message": "Username already exists. Choose another."}), 409

    return jsonify({"success": True, "message": "User registered successfully."})


@app.route('/auth/login', methods=['POST'])
def login_user():
    """
    Login endpoint returning a bearer token for subsequent calls.

    Example:
        curl -X POST http://localhost:5045/auth/login \
            -H "Content-Type: application/json" \
            -d '{"username": "demo", "password": "secret123"}'
    """
    data = request.get_json(force=True, silent=True) or {}
    username = data.get("username", "").strip()
    password = data.get("password", "")

    if not username or not password:
        return jsonify({"success": False, "message": "Username and password are required."}), 400

    token = user_service.login_user(username=username, password=password)
    if not token:
        return jsonify({"success": False, "message": "Invalid credentials."}), 401

    return jsonify({"success": True, "token": token})


@app.route('/users/images', methods=['POST'])
def upload_user_image():
    """
    Upload raw images for the authenticated user.

    Requires:
        - Authorization: Bearer <token> header obtained from /auth/login
        - multipart/form-data 'image' field containing the file

    Example:
        curl -X POST http://localhost:5045/users/images \
            -H "Authorization: Bearer <token>" \
            -F "image=@/path/photo.png"
    """
    token = _extract_token(request.headers.get("Authorization"))
    user = user_service.get_user_by_token(token)

    if not user:
        return jsonify({"success": False, "message": "Unauthorized. Login first."}), 401

    if 'image' not in request.files:
        return jsonify({"success": False, "message": "No image field provided."}), 400

    file = request.files['image']
    stored_path = user_service.save_user_image(
        user_id=user["id"],
        username=user["username"],
        file_storage=file,
    )

    if not stored_path:
        return jsonify({"success": False, "message": "Failed to save image."}), 400

    return jsonify(
        {
            "success": True,
            "message": "Image saved for user.",
            "stored_path": stored_path,
        }
    )


@app.route('/users/images', methods=['GET'])
def list_user_images():
    """
    List metadata for all images that belong to the logged-in user.

    Example:
        curl -X GET http://localhost:5045/users/images \
            -H "Authorization: Bearer <token>"
    """
    token = _extract_token(request.headers.get("Authorization"))
    user = user_service.get_user_by_token(token)

    if not user:
        return jsonify({"success": False, "message": "Unauthorized. Login first."}), 401

    images = user_service.list_user_images(user_id=user["id"])
    return jsonify({"success": True, "images": images})


@app.route('/remove-background', methods=['POST'])
def remove_background():
    """
    Remove background from uploaded image.
    
    Expects: multipart/form-data with 'image' field containing the image file
    Returns: Processed image with background removed (PNG format)
    
    Example usage:
        curl -X POST http://localhost:5045/remove-background \
             -F "image=@path/to/image.jpg"
    """
    try:
        # Check if image file is present in request
        if 'image' not in request.files:
            return jsonify({"error": "No image file provided"}), 400
        
        file = request.files['image']
        
        # Check if file is selected
        if file.filename == '':
            return jsonify({"error": "No file selected"}), 400
        
        # Read the image file
        input_image = Image.open(io.BytesIO(file.read()))
        
        # Remove background using rembg
        output_image = remove(input_image)
        
        # Convert to bytes
        img_byte_arr = io.BytesIO()
        output_image.save(img_byte_arr, format='PNG')
        img_byte_arr.seek(0)
        
        # Return the processed image
        return send_file(
            img_byte_arr,
            mimetype='image/png',
            as_attachment=False,
            download_name='processed_image.png'
        )
    
    except Exception as e:
        return jsonify({"error": f"Error processing image: {str(e)}"}), 500


@app.route('/remove-background-base64', methods=['POST'])
def remove_background_base64():
    """
    Remove background from base64 encoded image.
    
    Expects: JSON with 'image' field containing base64 encoded image string
    Returns: JSON with 'image' field containing base64 encoded processed image
    
    Example usage:
        {
            "image": "data:image/jpeg;base64,/9j/4AAQSkZJRg..."
        }
    """
    try:
        data = request.get_json()
        
        if not data or 'image' not in data:
            return jsonify({"error": "No image data provided"}), 400
        
        image_data = data['image']
        
        # Remove data URL prefix if present
        if ',' in image_data:
            image_data = image_data.split(',')[1]
        
        # Decode base64 image
        import base64
        image_bytes = base64.b64decode(image_data)
        
        # Open image
        input_image = Image.open(io.BytesIO(image_bytes))
        
        # Remove background
        output_image = remove(input_image)
        
        # Convert to base64
        img_byte_arr = io.BytesIO()
        output_image.save(img_byte_arr, format='PNG')
        img_byte_arr.seek(0)
        
        output_base64 = base64.b64encode(img_byte_arr.getvalue()).decode('utf-8')
        
        return jsonify({
            "success": True,
            "image": f"data:image/png;base64,{output_base64}"
        })
    
    except Exception as e:
        return jsonify({"error": f"Error processing image: {str(e)}"}), 500


if __name__ == '__main__':
    # Use port 5045 to avoid conflict with macOS AirPlay Receiver on port 5000
    PORT = 5045
    
    print("🚀 Starting Background Removal Server...")
    print(f"📍 Server will be available at: http://localhost:{PORT}")
    print(f"📡 Health check: http://localhost:{PORT}/health")
    print(f"🖼️  Remove background: http://localhost:{PORT}/remove-background")
    print("\n⚠️  Make sure your Flutter app is configured to connect to this server!")
    print(f"   For Android emulator, use: http://10.0.2.2:{PORT}")
    print(f"   For iOS simulator, use: http://localhost:{PORT}")
    print(f"   For physical device, use your computer's IP address (e.g., http://192.168.1.100:{PORT})\n")
    
    app.run(host='0.0.0.0', port=PORT, debug=True)


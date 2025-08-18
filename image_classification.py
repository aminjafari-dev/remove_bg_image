from transformers import AutoModelForImageClassification, AutoImageProcessor
from PIL import Image
import numpy as np
import cv2
import os
from rembg import remove
import torch

# Configuration
IMAGE_SIZE = (224, 224)  # Model expects 224x224
MODEL_NAME = "microsoft/swin-tiny-patch4-window7-224"  # Pre-trained model
OUTPUT_DIR = "processed_images"
DB = []  # Simple list to simulate database for clothing registration

# Ensure output directory exists
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

# Load pre-trained model and processor
def load_model_and_processor():
    processor = AutoImageProcessor.from_pretrained(MODEL_NAME)
    model = AutoModelForImageClassification.from_pretrained(MODEL_NAME)
    model.eval()  # Set to evaluation mode
    return model, processor

# Preprocess image for classification
def preprocess_image(image_path, processor):
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Could not load image: {image_path}")
    img = cv2.resize(img, IMAGE_SIZE)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)  # Convert to RGB
    img = Image.fromarray(img)
    inputs = processor(images=img, return_tensors="pt")
    return inputs

# Remove background and save the processed image
def remove_background(image_path, output_path):
    input_img = Image.open(image_path)
    output_img = remove(input_img)
    output_img.save(output_path)
    return output_path

# Classify image and store result
def classify_and_store(image_path, item_id):
    # Remove background
    output_path = os.path.join(OUTPUT_DIR, f"no_bg_{os.path.basename(image_path)}")
    processed_image_path = remove_background(image_path, output_path)
    
    # Load model and processor
    model, processor = load_model_and_processor()
    
    # Preprocess image
    inputs = preprocess_image(image_path, processor)
    
    # Predict
    with torch.no_grad():
        outputs = model(**inputs)
        logits = outputs.logits
        predicted_class = logits.argmax(-1).item()
    
    # Map prediction to shirt or pants (simplified, assumes binary mapping)
    # Note: This model isn't fine-tuned, so we use a heuristic
    clothing_type = "shirt" if predicted_class % 2 == 0 else "pants"  # Placeholder mapping
    
    # Store in "database"
    clothing_item = {
        'item_id': item_id,
        'type': clothing_type,
        'image_path': processed_image_path
    }
    DB.append(clothing_item)
    
    return clothing_type, processed_image_path

# Main function
def main():
    # Example usage
    image_path = 'images (3)_no_bg.png'  # Replace with your image path
    item_id = 1  # Unique ID for the clothing item
    
    try:
        # Classify and store
        clothing_type, processed_image_path = classify_and_store(image_path, item_id)
        print(f"Classified as: {clothing_type}")
        print(f"Processed image saved at: {processed_image_path}")
        print("Database entry:", DB)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
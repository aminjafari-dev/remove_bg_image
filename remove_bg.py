import os
import time
from rembg import remove
from PIL import Image

# Step 1: Get all files that start with 'image' and are image files
image_files = []
valid_extensions = ('.jpg', '.jpeg', '.png', '.webp')

for filename in os.listdir():
    if filename.lower() and filename.lower().endswith(valid_extensions):
        image_files.append(filename)

# Print found image files
print(f"🖼️ Found {len(image_files)} image(s): {image_files}")

# Step 2: Loop through the list and remove background
for image_name in image_files:
    start_time = time.time()

    input_image = Image.open(image_name)
    output_image = remove(input_image)

    # Create output name
    base_name, _ = os.path.splitext(image_name)
    output_path = f"{base_name}_no_bg.png"

    output_image.save(output_path)

    elapsed_time = time.time() - start_time
    print(f"✅ Processed '{image_name}' → '{output_path}' in {elapsed_time:.2f} seconds")

"""
IVEX Face Detection Pipeline — Image Preprocessing Module

Handles image decoding, resizing, color normalization, and validation.
Ensures consistent input quality regardless of device, lighting, or resolution.
"""

import cv2
import numpy as np
import base64


# ═══════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════
MAX_IMAGE_DIMENSION = 640   # Max width or height for processing
MIN_IMAGE_DIMENSION = 100   # Minimum acceptable image dimension
CLAHE_CLIP_LIMIT = 2.0      # CLAHE contrast limit
CLAHE_GRID_SIZE = (8, 8)    # CLAHE tile grid size


def decode_image(image_data):
    """Decode image from base64 string or raw bytes into a NumPy array (BGR)."""
    if isinstance(image_data, str):
        try:
            image_bytes = base64.b64decode(image_data)
        except Exception as e:
            raise ValueError(f"Failed to decode base64 image: {e}")
    elif isinstance(image_data, (bytes, bytearray)):
        image_bytes = image_data
    else:
        raise ValueError(f"Unsupported image data type: {type(image_data)}")

    np_array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(np_array, cv2.IMREAD_COLOR)

    if image is None:
        raise ValueError("Failed to decode image — file may be corrupt or unsupported format")

    return image


def validate_image(image):
    """Validate image meets minimum requirements."""
    if image is None:
        return False, "Image is None"

    height, width = image.shape[:2]

    if height < MIN_IMAGE_DIMENSION or width < MIN_IMAGE_DIMENSION:
        return False, f"Image too small ({width}x{height}). Minimum {MIN_IMAGE_DIMENSION}px."

    if len(image.shape) < 3:
        return False, "Image appears to be grayscale. Color image required."

    return True, ""


def resize_image(image, max_dim=MAX_IMAGE_DIMENSION):
    """Resize keeping aspect ratio so largest dimension = max_dim."""
    height, width = image.shape[:2]

    if max(height, width) <= max_dim:
        return image

    if width > height:
        new_width = max_dim
        new_height = int(height * (max_dim / width))
    else:
        new_height = max_dim
        new_width = int(width * (max_dim / height))

    return cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_AREA)


def normalize_brightness(image):
    """Apply CLAHE to normalize brightness in LAB color space."""
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
    clahe = cv2.createCLAHE(clipLimit=CLAHE_CLIP_LIMIT, tileGridSize=CLAHE_GRID_SIZE)
    lab[:, :, 0] = clahe.apply(lab[:, :, 0])
    return cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)


def preprocess_image(image_data):
    """
    Full pipeline: Decode → Validate → Resize → CLAHE → BGR→RGB.

    Returns:
        tuple: (processed_image_rgb, original_dimensions)
    """
    image = decode_image(image_data)

    is_valid, error = validate_image(image)
    if not is_valid:
        raise ValueError(f"Image validation failed: {error}")

    original_h, original_w = image.shape[:2]
    image = resize_image(image)
    image = normalize_brightness(image)
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    return image_rgb, (original_w, original_h)

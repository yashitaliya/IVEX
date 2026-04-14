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
    """
    Decode image from base64 string or raw bytes into a NumPy array.

    Args:
        image_data: base64-encoded string or raw bytes

    Returns:
        numpy.ndarray: Decoded image in BGR format

    Raises:
        ValueError: If image cannot be decoded
    """
    if isinstance(image_data, str):
        # Base64 encoded string
        try:
            image_bytes = base64.b64decode(image_data)
        except Exception as e:
            raise ValueError(f"Failed to decode base64 image: {e}")
    elif isinstance(image_data, (bytes, bytearray)):
        image_bytes = image_data
    else:
        raise ValueError(f"Unsupported image data type: {type(image_data)}")

    # Convert raw bytes → NumPy array → OpenCV image
    np_array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(np_array, cv2.IMREAD_COLOR)

    if image is None:
        raise ValueError(
            "Failed to decode image — file may be corrupt or unsupported format"
        )

    return image


def validate_image(image):
    """
    Validate that the image meets minimum requirements for face detection.

    Args:
        image: numpy.ndarray in BGR format

    Returns:
        tuple: (is_valid: bool, error_message: str)
    """
    if image is None:
        return False, "Image is None"

    height, width = image.shape[:2]

    if height < MIN_IMAGE_DIMENSION or width < MIN_IMAGE_DIMENSION:
        return False, (
            f"Image too small ({width}x{height}). "
            f"Minimum {MIN_IMAGE_DIMENSION}px required."
        )

    if len(image.shape) < 3:
        return False, "Image appears to be grayscale. Color image required."

    return True, ""


def resize_image(image, max_dim=MAX_IMAGE_DIMENSION):
    """
    Resize image so its largest dimension equals max_dim.
    Preserves aspect ratio. Skips if already small enough.

    Args:
        image: numpy.ndarray
        max_dim: Maximum dimension (width or height)

    Returns:
        numpy.ndarray: Resized image
    """
    height, width = image.shape[:2]

    if max(height, width) <= max_dim:
        return image  # Already within target size

    if width > height:
        new_width = max_dim
        new_height = int(height * (max_dim / width))
    else:
        new_height = max_dim
        new_width = int(width * (max_dim / height))

    return cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_AREA)


def normalize_brightness(image):
    """
    Apply CLAHE (Contrast Limited Adaptive Histogram Equalization)
    to normalize brightness and contrast across varying lighting conditions.

    Works in LAB color space — normalizes only the Lightness channel,
    preserving color information.

    Args:
        image: numpy.ndarray in BGR format

    Returns:
        numpy.ndarray: Brightness-normalized image in BGR format
    """
    # Convert BGR → LAB (L = lightness, A/B = color channels)
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)

    # Apply CLAHE to the L (lightness) channel only
    clahe = cv2.createCLAHE(
        clipLimit=CLAHE_CLIP_LIMIT,
        tileGridSize=CLAHE_GRID_SIZE
    )
    lab[:, :, 0] = clahe.apply(lab[:, :, 0])

    # Convert back LAB → BGR
    return cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)


def preprocess_image(image_data):
    """
    Full preprocessing pipeline:
      1. Decode (base64/bytes → NumPy)
      2. Validate (minimum size, color)
      3. Resize (consistent resolution)
      4. Normalize brightness (CLAHE)
      5. Convert BGR → RGB (MediaPipe expects RGB)

    Args:
        image_data: base64-encoded string or raw bytes

    Returns:
        tuple: (processed_image_rgb: numpy.ndarray, original_dimensions: (w, h))

    Raises:
        ValueError: If image is invalid or cannot be processed
    """
    # Step 1: Decode
    image = decode_image(image_data)

    # Step 2: Validate
    is_valid, error = validate_image(image)
    if not is_valid:
        raise ValueError(f"Image validation failed: {error}")

    original_h, original_w = image.shape[:2]

    # Step 3: Resize for consistent processing
    image = resize_image(image)

    # Step 4: Normalize brightness/contrast
    image = normalize_brightness(image)

    # Step 5: Convert BGR → RGB (MediaPipe requires RGB input)
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    return image_rgb, (original_w, original_h)

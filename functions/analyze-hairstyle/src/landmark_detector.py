"""
IVEX Face Detection Pipeline — Face Detection & Contour Analysis Module

Uses OpenCV Haar cascades for face detection and adaptive skin segmentation
for extracting the face contour/silhouette. This approach works on any platform
(including ARM) without needing MediaPipe.

The face contour is analyzed at different heights to extract widths at the
forehead, cheekbone, jaw, and chin levels — providing the same geometric
data as landmark-based approaches.
"""

import cv2
import numpy as np
import math


# ═══════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════
MIN_FACE_SIZE_RATIO = 0.08    # Minimum face size relative to image
CONTOUR_MIN_AREA_RATIO = 0.12  # Min contour area relative to ROI
MIN_ACCEPTABLE_CONFIDENCE = 0.30


class LandmarkDetectionError(Exception):
    """Custom exception for face detection failures."""
    pass


def detect_landmarks(image_rgb):
    """
    Detect face and extract facial contour using OpenCV.

    Uses Haar cascade for face detection, then adaptive skin color
    segmentation to extract the face silhouette. The contour is analyzed
    at key heights to produce geometric measurements.

    Args:
        image_rgb: numpy.ndarray in RGB format (from preprocess module)

    Returns:
        dict: {
            'analysis': dict with contour-derived measurements,
            'confidence': float (0-1),
            'image_shape': (height, width),
        }

    Raises:
        LandmarkDetectionError: If no face, multiple faces, or low confidence
    """
    # Convert RGB → BGR for OpenCV processing
    image_bgr = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)

    height, width = gray.shape
    min_face_px = int(min(width, height) * MIN_FACE_SIZE_RATIO)

    # ── Face detection using Haar cascade ──
    face_cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
    )

    faces = face_cascade.detectMultiScale(
        gray,
        scaleFactor=1.1,
        minNeighbors=5,
        minSize=(min_face_px, min_face_px),
        flags=cv2.CASCADE_SCALE_IMAGE,
    )

    if len(faces) == 0:
        # Try with more lenient parameters
        faces = face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.05,
            minNeighbors=3,
            minSize=(min_face_px, min_face_px),
        )

    if len(faces) == 0:
        raise LandmarkDetectionError(
            "No face detected in image. "
            "Please upload a clear, front-facing photo with good lighting."
        )

    if len(faces) > 1:
        # Pick the largest face if multiple detected
        # (slight tolerance — sometimes Haar cascade double-detects)
        areas = [w * h for (_, _, w, h) in faces]
        max_area = max(areas)
        significant_faces = [f for f, a in zip(faces, areas) if a > max_area * 0.5]

        if len(significant_faces) > 1:
            raise LandmarkDetectionError(
                "Multiple faces detected. "
                "Please upload a photo with only one person."
            )
        # Use the largest face
        faces = [faces[areas.index(max_area)]]

    fx, fy, fw, fh = faces[0]

    # ── Expand ROI for better contour detection ──
    margin_x = int(fw * 0.12)
    margin_y_top = int(fh * 0.10)
    margin_y_bot = int(fh * 0.08)

    roi_x = max(0, fx - margin_x)
    roi_y = max(0, fy - margin_y_top)
    roi_x2 = min(width, fx + fw + margin_x)
    roi_y2 = min(height, fy + fh + margin_y_bot)
    roi_w = roi_x2 - roi_x
    roi_h = roi_y2 - roi_y

    face_roi_bgr = image_bgr[roi_y:roi_y2, roi_x:roi_x2]

    if face_roi_bgr.size == 0:
        raise LandmarkDetectionError("Face region is empty after cropping.")

    # ── Extract face contour via adaptive skin segmentation ──
    contour = _extract_face_contour(face_roi_bgr, roi_w, roi_h)

    if contour is None:
        raise LandmarkDetectionError(
            "Could not extract face contour. "
            "Try a photo with more contrast between face and background."
        )

    # ── Analyze contour at different heights ──
    analysis = _analyze_contour(contour, roi_w, roi_h)

    # ── Estimate confidence ──
    face_size_ratio = fh / height
    confidence = _estimate_confidence(analysis, face_size_ratio)

    if confidence < MIN_ACCEPTABLE_CONFIDENCE:
        raise LandmarkDetectionError(
            "Face detection confidence too low. "
            "Please use a clearer photo with good lighting "
            "and minimal obstruction."
        )

    return {
        'analysis': analysis,
        'confidence': confidence,
        'image_shape': (height, width),
    }


def _extract_face_contour(face_roi_bgr, roi_w, roi_h):
    """
    Extract the face contour using adaptive skin color segmentation.

    Strategy:
      1. Sample skin color from the center of the face (reliable region)
      2. Build adaptive HSV thresholds from the sample
      3. Create binary mask → morphological cleanup → find largest contour

    This adapts to any skin tone and lighting condition.

    Args:
        face_roi_bgr: numpy.ndarray — face region in BGR
        roi_w, roi_h: int — ROI dimensions

    Returns:
        numpy.ndarray or None: largest face contour points
    """
    h, w = face_roi_bgr.shape[:2]

    if h < 20 or w < 20:
        return None

    hsv = cv2.cvtColor(face_roi_bgr, cv2.COLOR_BGR2HSV)

    # ── Sample skin color from center of face ──
    # The center of the detected face is almost certainly skin
    center_y, center_x = h // 2, w // 2
    sample_r = max(5, min(h, w) // 6)

    sy1 = max(0, center_y - sample_r)
    sy2 = min(h, center_y + sample_r)
    sx1 = max(0, center_x - sample_r)
    sx2 = min(w, center_x + sample_r)

    sample = hsv[sy1:sy2, sx1:sx2]

    if sample.size == 0:
        return None

    # ── Build adaptive thresholds from skin sample ──
    pixels = sample.reshape(-1, 3).astype(np.float32)
    mean_hsv = np.mean(pixels, axis=0)
    std_hsv = np.std(pixels, axis=0)

    # Use wider tolerance for more robust segmentation
    # Minimum std to prevent too-tight thresholds on uniform lighting
    min_std = np.array([8.0, 15.0, 20.0])
    effective_std = np.maximum(std_hsv, min_std)

    lower = np.array([
        max(0, mean_hsv[0] - 2.5 * effective_std[0]),
        max(15, mean_hsv[1] - 2.5 * effective_std[1]),
        max(30, mean_hsv[2] - 2.5 * effective_std[2]),
    ], dtype=np.uint8)

    upper = np.array([
        min(180, mean_hsv[0] + 2.5 * effective_std[0]),
        255,
        255,
    ], dtype=np.uint8)

    # ── Handle hue wraparound (reddish skin tones near H=0/180) ──
    if lower[0] > upper[0]:
        mask1 = cv2.inRange(hsv, np.array([0, lower[1], lower[2]]), upper)
        mask2 = cv2.inRange(hsv, lower, np.array([180, 255, 255]))
        mask = cv2.bitwise_or(mask1, mask2)
    else:
        mask = cv2.inRange(hsv, lower, upper)

    # ── Morphological cleanup ──
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=3)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=1)

    # Fill holes inside the face
    flood_mask = mask.copy()
    h_fill, w_fill = flood_mask.shape
    fill_mask = np.zeros((h_fill + 2, w_fill + 2), np.uint8)
    cv2.floodFill(flood_mask, fill_mask, (0, 0), 255)
    flood_mask_inv = cv2.bitwise_not(flood_mask)
    mask = cv2.bitwise_or(mask, flood_mask_inv)

    # ── Find contours ──
    contours, _ = cv2.findContours(
        mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )

    if not contours:
        return None

    # Select the largest contour
    largest = max(contours, key=cv2.contourArea)

    # Verify contour is large enough
    if cv2.contourArea(largest) < CONTOUR_MIN_AREA_RATIO * w * h:
        return None

    # ── Smooth the contour for cleaner measurements ──
    epsilon = 0.005 * cv2.arcLength(largest, True)
    largest = cv2.approxPolyDP(largest, epsilon, True)

    return largest


def _analyze_contour(contour, roi_w, roi_h):
    """
    Analyze face contour to extract widths at key facial height levels.

    Scans horizontal slices at:
      - 18% height → forehead width
      - 45% height → cheekbone width (typically widest)
      - 72% height → jaw width
      - 88% height → chin width

    Args:
        contour: numpy.ndarray — face contour points
        roi_w, roi_h: int — ROI dimensions for normalization

    Returns:
        dict: raw analysis data (all values normalized 0-1)
    """
    cx, cy, cw, ch = cv2.boundingRect(contour)

    if ch == 0 or cw == 0:
        return _empty_analysis()

    # ── Define height levels ──
    forehead_y = cy + int(ch * 0.18)
    cheekbone_y = cy + int(ch * 0.45)
    jaw_y = cy + int(ch * 0.72)
    chin_y = cy + int(ch * 0.88)

    # ── Measure widths at each level ──
    forehead_width = _width_at_height(contour, forehead_y)
    cheekbone_width = _width_at_height(contour, cheekbone_y)
    jaw_width = _width_at_height(contour, jaw_y)
    chin_width = _width_at_height(contour, chin_y)

    # ── Fallback: try wider tolerance if measurement failed ──
    if cheekbone_width == 0:
        for offset in range(-5, 6):
            cheekbone_width = _width_at_height(
                contour, cheekbone_y + offset * 2
            )
            if cheekbone_width > 0:
                break

    if cheekbone_width == 0:
        cheekbone_width = cw  # Fallback to bounding rect width

    # ── Find chin point (bottommost) ──
    bottommost_idx = contour[:, :, 1].argmax()
    chin_point = tuple(contour[bottommost_idx][0])

    # ── Find jaw angle points ──
    left_jaw, right_jaw = _find_jaw_points(contour, jaw_y, cx, cw)

    # ── Calculate jawline angle at chin ──
    jawline_angle = _angle_at_vertex(left_jaw, chin_point, right_jaw)

    return {
        'forehead_width': forehead_width / roi_w if roi_w > 0 else 0,
        'cheekbone_width': cheekbone_width / roi_w if roi_w > 0 else 0,
        'jaw_width': jaw_width / roi_w if roi_w > 0 else 0,
        'chin_width': chin_width / roi_w if roi_w > 0 else 0,
        'face_height': ch / roi_h if roi_h > 0 else 0,
        'jawline_angle': jawline_angle,
        'chin_point': chin_point,
        'left_jaw': left_jaw,
        'right_jaw': right_jaw,
    }


def _width_at_height(contour, target_y, tolerance=4):
    """
    Find the contour width at a given y-coordinate.

    Scans all contour points near target_y and returns the
    distance between the leftmost and rightmost points.

    Args:
        contour: contour points array
        target_y: y-coordinate to measure at
        tolerance: pixel tolerance for point selection

    Returns:
        int: width in pixels (0 if not enough points found)
    """
    points_near_y = []
    for pt in contour:
        if abs(pt[0][1] - target_y) <= tolerance:
            points_near_y.append(pt[0][0])

    if len(points_near_y) < 2:
        # Try with bigger tolerance
        for pt in contour:
            if abs(pt[0][1] - target_y) <= tolerance * 2:
                points_near_y.append(pt[0][0])

    if len(points_near_y) < 2:
        return 0

    return max(points_near_y) - min(points_near_y)


def _find_jaw_points(contour, jaw_y, bbox_x, bbox_w):
    """
    Find the leftmost and rightmost contour points at jaw height.

    Args:
        contour: contour points
        jaw_y: y-coordinate of jaw level
        bbox_x, bbox_w: bounding box x and width (for defaults)

    Returns:
        tuple: (left_jaw_point, right_jaw_point) as (x, y) tuples
    """
    center_x = bbox_x + bbox_w // 2
    left_pts = []
    right_pts = []

    for pt in contour:
        if abs(pt[0][1] - jaw_y) <= 6:
            if pt[0][0] < center_x:
                left_pts.append(tuple(pt[0]))
            else:
                right_pts.append(tuple(pt[0]))

    left_jaw = min(left_pts, key=lambda p: p[0]) if left_pts else (bbox_x, jaw_y)
    right_jaw = (
        max(right_pts, key=lambda p: p[0])
        if right_pts
        else (bbox_x + bbox_w, jaw_y)
    )

    return left_jaw, right_jaw


def _angle_at_vertex(p1, vertex, p2):
    """
    Calculate the angle at the vertex point formed by p1-vertex-p2.

    Args:
        p1, p2: endpoint tuples (x, y)
        vertex: vertex tuple (x, y)

    Returns:
        float: angle in degrees (0-180)
    """
    v1 = (p1[0] - vertex[0], p1[1] - vertex[1])
    v2 = (p2[0] - vertex[0], p2[1] - vertex[1])

    dot = v1[0] * v2[0] + v1[1] * v2[1]
    mag1 = math.sqrt(v1[0] ** 2 + v1[1] ** 2)
    mag2 = math.sqrt(v2[0] ** 2 + v2[1] ** 2)

    if mag1 == 0 or mag2 == 0:
        return 90.0  # Default to right angle

    cos_angle = max(-1.0, min(1.0, dot / (mag1 * mag2)))
    return math.degrees(math.acos(cos_angle))


def _estimate_confidence(analysis, face_size_ratio):
    """
    Estimate detection confidence from analysis quality indicators.

    Args:
        analysis: dict from _analyze_contour
        face_size_ratio: float — face height / image height

    Returns:
        float: confidence between 0.0 and 1.0
    """
    scores = []

    # Face should be a reasonable size in the image
    scores.append(1.0 if 0.12 <= face_size_ratio <= 0.95 else 0.5)

    # Cheekbone width should be detected
    scores.append(1.0 if analysis['cheekbone_width'] > 0.05 else 0.3)

    # Face height should be meaningful
    scores.append(1.0 if analysis['face_height'] > 0.10 else 0.3)

    # Jaw width should be detected
    scores.append(1.0 if analysis['jaw_width'] > 0.03 else 0.4)

    # Forehead width should be detected
    scores.append(1.0 if analysis['forehead_width'] > 0.03 else 0.5)

    # Jawline angle should be reasonable (40-150 degrees)
    angle = analysis.get('jawline_angle', 90)
    scores.append(1.0 if 40 <= angle <= 150 else 0.5)

    return round(sum(scores) / len(scores), 2)


def _empty_analysis():
    """Return an empty analysis dict for error cases."""
    return {
        'forehead_width': 0,
        'cheekbone_width': 0,
        'jaw_width': 0,
        'chin_width': 0,
        'face_height': 0,
        'jawline_angle': 90,
        'chin_point': (0, 0),
        'left_jaw': (0, 0),
        'right_jaw': (0, 0),
    }

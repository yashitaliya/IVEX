"""
IVEX Face Detection Pipeline — Geometric Measurements from MediaPipe Landmarks

Extracts scale-independent facial ratios from 468-point MediaPipe landmarks.
All measurements are normalized ratios suitable for deterministic classification.
"""

import math


# ═══════════════════════════════════════════════════
# MEDIAPIPE LANDMARK INDICES (468-point mesh)
# ═══════════════════════════════════════════════════
FOREHEAD_TOP = 10
CHIN_TIP = 152
LEFT_CHEEKBONE = 234
RIGHT_CHEEKBONE = 454
LEFT_JAW = 172
RIGHT_JAW = 397
LEFT_FOREHEAD = 21
RIGHT_FOREHEAD = 251
NOSE_TIP = 1

# Jawline contour points (for chin width estimation)
JAWLINE_LEFT = [172, 136, 150, 149, 176, 148]
JAWLINE_RIGHT = [397, 365, 379, 378, 400, 377]


def _distance(p1, p2):
    """Euclidean distance between two landmark points."""
    return math.sqrt((p1["x"] - p2["x"]) ** 2 + (p1["y"] - p2["y"]) ** 2)


def _angle(p1, vertex, p2):
    """Angle at vertex formed by p1-vertex-p2 (degrees)."""
    v1 = (p1["x"] - vertex["x"], p1["y"] - vertex["y"])
    v2 = (p2["x"] - vertex["x"], p2["y"] - vertex["y"])

    dot = v1[0] * v2[0] + v1[1] * v2[1]
    mag1 = math.sqrt(v1[0] ** 2 + v1[1] ** 2)
    mag2 = math.sqrt(v2[0] ** 2 + v2[1] ** 2)

    if mag1 == 0 or mag2 == 0:
        return 90.0

    cos_a = max(-1.0, min(1.0, dot / (mag1 * mag2)))
    return math.degrees(math.acos(cos_a))


def extract_measurements(landmarks):
    """
    Extract normalized facial measurement ratios from MediaPipe landmarks.

    Args:
        landmarks: list of 468 dicts with 'x', 'y', 'z' keys (normalized 0-1)

    Returns:
        dict: Scale-independent ratios for the classifier.

    Raises:
        ValueError: If face is too small or partially visible.
    """
    # ── Core distances ──
    face_height = _distance(landmarks[FOREHEAD_TOP], landmarks[CHIN_TIP])
    face_width = _distance(landmarks[LEFT_CHEEKBONE], landmarks[RIGHT_CHEEKBONE])
    jaw_width = _distance(landmarks[LEFT_JAW], landmarks[RIGHT_JAW])
    forehead_width = _distance(landmarks[LEFT_FOREHEAD], landmarks[RIGHT_FOREHEAD])

    if face_height < 0.01 or face_width < 0.01:
        raise ValueError(
            "Face measurements too small — "
            "face may be partially visible or too far from camera."
        )

    # ── Ratios ──
    width_height_ratio = face_width / face_height
    jaw_cheek_ratio = jaw_width / face_width if face_width > 0.01 else 0
    forehead_cheek_ratio = forehead_width / face_width if face_width > 0.01 else 0

    # ── Jawline angle at chin ──
    jawline_angle = _angle(
        landmarks[LEFT_JAW], landmarks[CHIN_TIP], landmarks[RIGHT_JAW]
    )
    jawline_angle_normalized = max(0.0, min(1.0, (jawline_angle - 60) / 60))

    # ── Chin ratio ──
    chin_left = landmarks[JAWLINE_LEFT[-1]]
    chin_right = landmarks[JAWLINE_RIGHT[-1]]
    chin_width = _distance(chin_left, chin_right)
    chin_ratio = chin_width / jaw_width if jaw_width > 0.01 else 0

    return {
        "face_height": round(face_height, 4),
        "face_width": round(face_width, 4),
        "jaw_width": round(jaw_width, 4),
        "forehead_width": round(forehead_width, 4),
        "width_height_ratio": round(width_height_ratio, 4),
        "jaw_cheek_ratio": round(jaw_cheek_ratio, 4),
        "forehead_cheek_ratio": round(forehead_cheek_ratio, 4),
        "jawline_angle": round(jawline_angle, 2),
        "jawline_angle_normalized": round(jawline_angle_normalized, 4),
        "chin_ratio": round(chin_ratio, 4),
    }

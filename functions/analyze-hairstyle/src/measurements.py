"""
IVEX Face Detection Pipeline — Facial Measurements Module

Extracts normalized geometric ratios from face contour analysis data.
All measurements are scale-independent ratios suitable for classification.

This module bridges the contour analyzer (landmark_detector.py) and
the classifier (classifier.py), converting raw contour widths into
the same ratio format the classifier expects.
"""

import math


def extract_measurements(detection_result):
    """
    Extract normalized facial measurement ratios from contour analysis.

    Takes the raw analysis data from landmark_detector.detect_landmarks()
    and produces scale-independent ratios that the classifier uses.

    Args:
        detection_result: dict from detect_landmarks(), containing 'analysis' key

    Returns:
        dict: {
            'face_height': float,
            'face_width': float,
            'jaw_width': float,
            'forehead_width': float,
            'width_height_ratio': float,       # cheekbone_width / face_height
            'jaw_cheek_ratio': float,          # jaw_width / cheekbone_width
            'forehead_cheek_ratio': float,     # forehead_width / cheekbone_width
            'jawline_angle': float,            # degrees
            'jawline_angle_normalized': float, # 0 (sharp) to 1 (soft)
            'chin_ratio': float,               # chin_width / jaw_width
        }

    Raises:
        ValueError: If measurements are too small (face partially visible)
    """
    analysis = detection_result['analysis']

    face_height = analysis['face_height']
    cheekbone_width = analysis['cheekbone_width']
    jaw_width = analysis['jaw_width']
    forehead_width = analysis['forehead_width']
    chin_width = analysis['chin_width']
    jawline_angle = analysis['jawline_angle']

    # ── Validate: face must be visible enough for measurement ──
    if face_height < 0.05 or cheekbone_width < 0.03:
        raise ValueError(
            "Face measurements too small — "
            "face may be partially visible or too far away from camera."
        )

    # ── Compute normalized ratios ──
    width_height_ratio = cheekbone_width / face_height

    jaw_cheek_ratio = (
        jaw_width / cheekbone_width if cheekbone_width > 0.01 else 0.0
    )

    forehead_cheek_ratio = (
        forehead_width / cheekbone_width if cheekbone_width > 0.01 else 0.0
    )

    chin_ratio = (
        chin_width / jaw_width if jaw_width > 0.01 else 0.0
    )

    # ── Normalize jawline angle ──
    # Typical range: 60° (very sharp/angular) to 120° (very wide/soft)
    # Map to 0.0 (sharpest) → 1.0 (softest)
    jawline_angle_normalized = max(0.0, min(1.0, (jawline_angle - 60) / 60))

    return {
        'face_height': round(face_height, 4),
        'face_width': round(cheekbone_width, 4),
        'jaw_width': round(jaw_width, 4),
        'forehead_width': round(forehead_width, 4),
        'width_height_ratio': round(width_height_ratio, 4),
        'jaw_cheek_ratio': round(jaw_cheek_ratio, 4),
        'forehead_cheek_ratio': round(forehead_cheek_ratio, 4),
        'jawline_angle': round(jawline_angle, 2),
        'jawline_angle_normalized': round(jawline_angle_normalized, 4),
        'chin_ratio': round(chin_ratio, 4),
    }

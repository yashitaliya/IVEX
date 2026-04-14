"""
IVEX Face Detection Pipeline — Face Shape Classifier

Classifies face shape using a weighted Gaussian scoring system.

Each shape has an ideal measurement profile. The classifier scores how well
the actual measurements match each profile using Gaussian distance functions.
The shape with the highest weighted score wins.

Design guarantees:
  - Deterministic output (always exactly 1 result)
  - No overlapping ambiguity (scores compete, highest wins)
  - Confidence from score distribution (clear winner = high confidence)
"""

import math


# ═══════════════════════════════════════════════════
# FACE SHAPE IDENTIFIERS
# ═══════════════════════════════════════════════════
ROUND = "round"
OVAL = "oval"
SQUARE = "square"
HEART = "heart"
DIAMOND = "diamond"
OBLONG = "oblong"

ALL_SHAPES = [ROUND, OVAL, SQUARE, HEART, DIAMOND, OBLONG]


def _gaussian_score(value, ideal, sigma):
    """
    Gaussian-based score: how close a measured value is to an ideal value.
    Returns 1.0 when value == ideal, decreasing smoothly as they diverge.

    Args:
        value: The measured value
        ideal: The target value for this face shape
        sigma: Standard deviation (controls tolerance width)

    Returns:
        float: Score between 0.0 and 1.0
    """
    return math.exp(-0.5 * ((value - ideal) / sigma) ** 2)


# ═══════════════════════════════════════════════════
# SHAPE SCORING FUNCTIONS
# Each returns a weighted average score for how well
# the measurements match that shape's ideal profile.
# ═══════════════════════════════════════════════════

def _score_round(m):
    """
    ROUND: Width ≈ Height, full cheeks, soft/wide jawline.
    Think: Leonardo DiCaprio, Jack Black
    """
    scores = [
        # Width close to height (ratio near 1.0)
        _gaussian_score(m['width_height_ratio'], 0.95, 0.08) * 2.0,
        # Jaw nearly as wide as cheeks (round, full jaw)
        _gaussian_score(m['jaw_cheek_ratio'], 0.88, 0.08) * 1.5,
        # Soft jawline (high normalized angle = wide/rounded)
        _gaussian_score(m['jawline_angle_normalized'], 0.75, 0.15) * 1.5,
        # Forehead similar to cheekbone width
        _gaussian_score(m['forehead_cheek_ratio'], 0.90, 0.10) * 1.0,
    ]
    return sum(scores) / len(scores)


def _score_oval(m):
    """
    OVAL: Height > Width, balanced proportions, gentle jawline.
    Think: George Clooney, Ryan Gosling
    """
    scores = [
        # Height slightly greater than width
        _gaussian_score(m['width_height_ratio'], 0.78, 0.08) * 2.0,
        # Balanced jaw-to-cheek ratio
        _gaussian_score(m['jaw_cheek_ratio'], 0.80, 0.08) * 1.5,
        # Moderate jawline angle (not too sharp, not too soft)
        _gaussian_score(m['jawline_angle_normalized'], 0.55, 0.15) * 1.0,
        # Forehead slightly narrower than cheeks
        _gaussian_score(m['forehead_cheek_ratio'], 0.88, 0.10) * 1.0,
    ]
    return sum(scores) / len(scores)


def _score_square(m):
    """
    SQUARE: Strong angular jawline, Width ≈ Height, prominent jaw.
    Think: Brad Pitt, Henry Cavill
    """
    scores = [
        # Width close to height
        _gaussian_score(m['width_height_ratio'], 0.90, 0.08) * 1.5,
        # Strong jaw — nearly as wide as cheekbones
        _gaussian_score(m['jaw_cheek_ratio'], 0.90, 0.06) * 2.0,
        # Angular jawline (low normalized angle = sharp)
        _gaussian_score(m['jawline_angle_normalized'], 0.35, 0.15) * 2.0,
        # Forehead similar to jaw/cheek width
        _gaussian_score(m['forehead_cheek_ratio'], 0.92, 0.08) * 1.0,
    ]
    return sum(scores) / len(scores)


def _score_heart(m):
    """
    HEART: Wide forehead, narrow chin/jaw, prominent cheekbones.
    Think: Ryan Reynolds, Keanu Reeves
    """
    scores = [
        # Wide forehead relative to cheeks
        _gaussian_score(m['forehead_cheek_ratio'], 1.00, 0.08) * 2.0,
        # Narrow jaw relative to cheeks
        _gaussian_score(m['jaw_cheek_ratio'], 0.70, 0.08) * 2.0,
        # Narrow chin
        _gaussian_score(m['chin_ratio'], 0.50, 0.12) * 1.5,
        # Moderate to slightly longer face
        _gaussian_score(m['width_height_ratio'], 0.80, 0.10) * 1.0,
    ]
    return sum(scores) / len(scores)


def _score_diamond(m):
    """
    DIAMOND: Wide cheekbones, narrow forehead + narrow jaw.
    Think: Johnny Depp, Robert Pattinson
    """
    scores = [
        # Narrow forehead relative to cheeks
        _gaussian_score(m['forehead_cheek_ratio'], 0.78, 0.08) * 2.0,
        # Narrow jaw relative to cheeks
        _gaussian_score(m['jaw_cheek_ratio'], 0.72, 0.08) * 2.0,
        # Both forehead and jaw narrower than cheeks (cheek prominence)
        min((1.0 - m['forehead_cheek_ratio']) + (1.0 - m['jaw_cheek_ratio']), 1.0) * 1.5,
        # Moderate height ratio
        _gaussian_score(m['width_height_ratio'], 0.80, 0.10) * 1.0,
    ]
    return sum(scores) / len(scores)


def _score_oblong(m):
    """
    OBLONG: Height >> Width, straight sides, elongated face.
    Think: Adam Driver, Ben Affleck
    """
    scores = [
        # Height significantly greater than width (low ratio)
        _gaussian_score(m['width_height_ratio'], 0.68, 0.07) * 2.5,
        # Jaw and cheek similar width (straight sides)
        _gaussian_score(m['jaw_cheek_ratio'], 0.82, 0.08) * 1.5,
        # Forehead similar to cheekbone width
        _gaussian_score(m['forehead_cheek_ratio'], 0.90, 0.10) * 1.0,
        # Moderate jawline
        _gaussian_score(m['jawline_angle_normalized'], 0.50, 0.15) * 1.0,
    ]
    return sum(scores) / len(scores)


# Scoring function registry
_SHAPE_SCORERS = {
    ROUND: _score_round,
    OVAL: _score_oval,
    SQUARE: _score_square,
    HEART: _score_heart,
    DIAMOND: _score_diamond,
    OBLONG: _score_oblong,
}


def classify_face_shape(measurements):
    """
    Classify face shape using weighted Gaussian scoring.

    Each shape's scoring function evaluates how well the actual measurements
    match its ideal profile. The highest-scoring shape is selected.
    Confidence is derived from how dominant the winner is relative to others.

    Args:
        measurements: dict from measurements.extract_measurements()

    Returns:
        dict: {
            'face_shape': str,       # Detected shape name
            'confidence': float,     # Confidence 0.0–1.0
            'all_scores': dict,      # Score for each shape (debug info)
        }
    """
    # Calculate score for every face shape
    scores = {}
    for shape, scorer in _SHAPE_SCORERS.items():
        scores[shape] = scorer(measurements)

    # Winner = highest score
    best_shape = max(scores, key=scores.get)
    best_score = scores[best_shape]

    # Confidence = how dominant the winner is
    # Using softmax-style ratio: best / total
    total = sum(scores.values())
    if total > 0:
        raw_confidence = best_score / total
    else:
        raw_confidence = 0.0

    # Scale to intuitive range:
    #   - Random chance with 6 shapes = ~0.167
    #   - A clear winner at 0.33+ should map to high confidence
    #   - Cap at 1.0
    confidence = min(1.0, raw_confidence * 3.0)
    confidence = round(confidence, 2)

    # Round scores for cleanliness
    scores = {k: round(v, 4) for k, v in scores.items()}

    return {
        'face_shape': best_shape,
        'confidence': confidence,
        'all_scores': scores,
    }

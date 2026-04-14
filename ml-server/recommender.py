"""
IVEX Face Detection Pipeline — Hairstyle Recommendation Engine

Pure logic-based recommendation system mapped to face shapes.
No AI/ML involved — curated mappings that are easy to update.
"""


# ═══════════════════════════════════════════════════
# HAIRSTYLE RECOMMENDATIONS DATABASE
# Curated by face shape for men's hairstyles
# ═══════════════════════════════════════════════════

RECOMMENDATIONS = {
    "round": {
        "recommended": [
            "Pompadour",
            "Undercut",
            "Side Part",
            "Faux Hawk",
            "Quiff",
            "Textured Spikes",
        ],
        "avoid": [
            "Bowl Cut",
            "Blunt Bangs",
            "Round Layers",
            "Chin-Length Bob",
        ],
        "tip": (
            "Add height and angles on top to elongate your face. "
            "Keep sides short and tight. A side part creates asymmetry "
            "that breaks the roundness."
        ),
        "prompt_style": "tall pompadour with undercut sides, textured volume on top",
    },
    "oval": {
        "recommended": [
            "Textured Crop",
            "Buzz Cut",
            "Side Swept",
            "Classic Taper",
            "Layered Cut",
            "Slicked Back",
        ],
        "avoid": [
            "Heavy bangs that cover the forehead",
            "Overly long face-covering styles",
        ],
        "tip": (
            "You have the most versatile face shape — most styles work well. "
            "Experiment freely. A textured crop or classic taper "
            "is always a safe, timeless choice."
        ),
        "prompt_style": "classic textured crop with tapered sides, natural volume",
    },
    "square": {
        "recommended": [
            "Textured Crop",
            "Messy Fringe",
            "Side Part",
            "Medium Length Waves",
            "Tousled Top",
            "Angular Fringe",
        ],
        "avoid": [
            "Flat Top",
            "Very Short Buzz Cut",
            "Blunt straight-across bangs",
        ],
        "tip": (
            "Soften your strong jawline with textured, layered cuts. "
            "A messy fringe adds a relaxed contrast to angular features. "
            "Medium length on top works best."
        ),
        "prompt_style": "textured messy fringe with soft layers, medium length on top",
    },
    "heart": {
        "recommended": [
            "Side Swept Bangs",
            "Textured Waves",
            "Medium Length Layers",
            "Chin-Length Fringe",
            "Curtain Bangs",
            "Low Fade with Texture",
        ],
        "avoid": [
            "Slicked Back",
            "High Volume Pompadour",
            "Styles that add width at temples",
        ],
        "tip": (
            "Balance your wider forehead with styles that add volume "
            "at the jawline. Side-swept bangs or curtain bangs create "
            "proportional harmony. Avoid adding height on top."
        ),
        "prompt_style": "side swept bangs with medium texture, soft layers around chin",
    },
    "diamond": {
        "recommended": [
            "Fringe Styles",
            "Side Part with Volume",
            "Textured Crop",
            "Chin-Length Layers",
            "Curtain Bangs",
            "Tapered Sides with Top Volume",
        ],
        "avoid": [
            "Completely Slicked Back",
            "Very Short Sides with No Top Volume",
            "Styles that emphasize cheekbone width",
        ],
        "tip": (
            "Add width at the forehead and chin to balance your prominent "
            "cheekbones. A fringe or bangs softens the forehead, while "
            "chin-length layers add jawline volume."
        ),
        "prompt_style": "fringe with textured top, tapered sides, chin-level layers",
    },
    "oblong": {
        "recommended": [
            "Side Swept Bangs",
            "Fringe / Bangs",
            "Layered Crop",
            "Textured Side Part",
            "Waves with Volume at Sides",
            "Short to Medium Length All-Over",
        ],
        "avoid": [
            "Very Long on Top",
            "High Pompadour",
            "Styles that add vertical length",
            "Tight sides with no width",
        ],
        "tip": (
            "Add width at the sides and use bangs to visually shorten the face. "
            "Avoid styles that add extra height on top. "
            "Layers and side volume create better proportions."
        ),
        "prompt_style": "side swept bangs with layered sides, medium volume all around",
    },
}


def get_recommendations(face_shape):
    """
    Get hairstyle recommendations for a detected face shape.

    Args:
        face_shape: str — one of: round, oval, square, heart, diamond, oblong

    Returns:
        dict: {
            'recommended': list[str] — hairstyle names to try,
            'avoid': list[str] — styles to avoid,
            'tip': str — styling advice,
            'prompt_style': str — for image generation prompt,
        }
    """
    shape_key = face_shape.lower().strip()

    if shape_key not in RECOMMENDATIONS:
        # Fallback to oval (most versatile) for unknown shapes
        shape_key = "oval"

    # Return a copy to prevent mutation of the global data
    return RECOMMENDATIONS[shape_key].copy()


def generate_advice_text(face_shape, measurements, confidence):
    """
    Generate a human-readable advice paragraph combining analysis data.

    Args:
        face_shape: str
        measurements: dict of facial measurements
        confidence: float (0-1)

    Returns:
        str: Formatted advice text
    """
    recs = get_recommendations(face_shape)

    confidence_pct = int(confidence * 100)
    shape_display = face_shape.capitalize()

    top_styles = ", ".join(recs['recommended'][:3])
    avoid_styles = ", ".join(recs['avoid'][:2])

    text = (
        f"Your face shape is {shape_display} "
        f"(detected with {confidence_pct}% confidence). "
        f"{recs['tip']} "
        f"Top recommended styles: {top_styles}. "
        f"Styles to avoid: {avoid_styles}."
    )

    return text


def generate_pollinations_prompt(face_shape):
    """
    Generate a prompt for Pollinations.ai image generation.

    Args:
        face_shape: str

    Returns:
        str: Image generation prompt
    """
    recs = get_recommendations(face_shape)
    prompt_style = recs.get('prompt_style', 'modern stylish haircut')

    return f"man with {prompt_style}, professional studio portrait, cinematic lighting"

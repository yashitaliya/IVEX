"""
IVEX Face Analysis — ML Server (Flask API)

Standalone Python server running MediaPipe Face Mesh + geometric analysis.
Deployed on Render.com (or any standard Linux host).

Endpoints:
  GET  /health   → health check
  POST /analyze  → face shape analysis
"""

import os
import base64
import traceback

from flask import Flask, request, jsonify
from flask_cors import CORS

from preprocess import preprocess_image
from landmark_detector import detect_landmarks, LandmarkDetectionError
from measurements import extract_measurements
from classifier import classify_face_shape
from recommender import (
    get_recommendations,
    generate_advice_text,
    generate_pollinations_prompt,
)

app = Flask(__name__)
CORS(app)  # Allow cross-origin requests from Appwrite functions


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    return jsonify({"status": "healthy", "service": "ivex-face-analysis"})


@app.route("/analyze", methods=["POST"])
def analyze():
    """
    Analyze a face image and return shape classification + recommendations.

    Accepts JSON body:
      { "image": "<base64-encoded image>" }

    Returns JSON:
      {
        "success": true,
        "faceShape": "oval",
        "confidence": 0.87,
        "measurements": { ... },
        "recommendations": { ... },
        "advice": "Your face shape is Oval ..."
      }
    """
    try:
        data = request.get_json(silent=True)

        if not data or "image" not in data:
            return jsonify({"success": False, "error": "No image provided. Send JSON with 'image' key (base64)."}), 400

        # ── Decode base64 image ──
        try:
            image_bytes = base64.b64decode(data["image"])
        except Exception:
            return jsonify({"success": False, "error": "Invalid base64 image data."}), 400

        if len(image_bytes) < 1000:
            return jsonify({"success": False, "error": "Image too small or corrupt."}), 400

        # ══════════════════════════════════════
        # PIPELINE
        # ══════════════════════════════════════

        # Step 1: Preprocess
        processed_image, original_dims = preprocess_image(image_bytes)

        # Step 2: Detect landmarks (MediaPipe Face Mesh — 468 points)
        detection_result = detect_landmarks(processed_image)
        landmarks = detection_result["landmarks"]
        detection_confidence = detection_result["confidence"]

        # Step 3: Extract geometric measurements
        face_measurements = extract_measurements(landmarks)

        # Step 4: Classify face shape
        classification = classify_face_shape(face_measurements)
        face_shape = classification["face_shape"]
        shape_confidence = classification["confidence"]

        # Step 5: Get recommendations
        recommendations = get_recommendations(face_shape)
        advice_text = generate_advice_text(face_shape, face_measurements, shape_confidence)

        return jsonify({
            "success": True,
            "faceDetected": True,
            "faceShape": face_shape,
            "confidence": shape_confidence,
            "measurements": {
                "widthHeightRatio": face_measurements["width_height_ratio"],
                "jawCheekRatio": face_measurements["jaw_cheek_ratio"],
                "foreheadCheekRatio": face_measurements["forehead_cheek_ratio"],
                "jawlineAngle": face_measurements["jawline_angle_normalized"],
            },
            "recommendations": {
                "recommended": recommendations["recommended"],
                "avoid": recommendations["avoid"],
                "tip": recommendations["tip"],
            },
            "advice": advice_text,
        })

    except LandmarkDetectionError as e:
        return jsonify({
            "success": False,
            "faceDetected": False,
            "error": str(e),
        }), 200

    except ValueError as e:
        return jsonify({
            "success": False,
            "faceDetected": False,
            "error": str(e),
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({
            "success": False,
            "error": f"Processing failed: {e}",
        }), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)

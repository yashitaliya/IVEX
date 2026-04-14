"""
IVEX Face Detection Pipeline — MediaPipe Face Mesh Landmark Detector

Uses MediaPipe's 468-point Face Mesh for precise facial landmark detection.
This runs on the ML server (standard Linux), NOT on Appwrite (Alpine).
"""

import mediapipe as mp
import numpy as np
import math


class LandmarkDetectionError(Exception):
    """Custom exception for face detection failures."""
    pass


def detect_landmarks(image_rgb):
    """
    Detect 468 facial landmarks using MediaPipe Face Mesh.

    Args:
        image_rgb: numpy.ndarray in RGB format

    Returns:
        dict: {
            'landmarks': list of {'x', 'y', 'z'} dicts (normalized 0-1),
            'confidence': float (0-1),
            'image_shape': (height, width),
        }

    Raises:
        LandmarkDetectionError: No face, multiple faces, or low quality
    """
    mp_face_mesh = mp.solutions.face_mesh

    with mp_face_mesh.FaceMesh(
        static_image_mode=True,
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    ) as face_mesh:
        results = face_mesh.process(image_rgb)

        if not results.multi_face_landmarks:
            raise LandmarkDetectionError(
                "No face detected in image. "
                "Please upload a clear, front-facing photo with good lighting."
            )

        if len(results.multi_face_landmarks) > 1:
            raise LandmarkDetectionError(
                "Multiple faces detected. "
                "Please upload a photo with only one person."
            )

        face_landmarks = results.multi_face_landmarks[0]
        h, w = image_rgb.shape[:2]

        # Extract normalized coordinates
        landmarks = []
        for lm in face_landmarks.landmark:
            landmarks.append({
                "x": lm.x,
                "y": lm.y,
                "z": lm.z,
            })

        # Estimate confidence from landmark depth consistency
        z_values = [lm["z"] for lm in landmarks]
        z_std = np.std(z_values)
        confidence = min(1.0, max(0.3, 1.0 - z_std * 5))

        return {
            "landmarks": landmarks,
            "confidence": round(confidence, 2),
            "image_shape": (h, w),
        }

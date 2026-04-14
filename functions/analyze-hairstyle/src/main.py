"""
IVEX Hairstyle Analysis — Appwrite Cloud Function (Thin Proxy)

This function:
  1. Downloads the uploaded image from Appwrite Storage
  2. Sends it to the external ML server for face analysis
  3. Stores the results in Appwrite Database

The heavy ML processing (MediaPipe, OpenCV) runs on a separate
Python server deployed on Render.com — not in Appwrite.
"""

import os
import json
import time
import base64
import random
import urllib.parse
import requests

from appwrite.client import Client
from appwrite.services.storage import Storage
from appwrite.services.databases import Databases
from appwrite.id import ID


def main(context):
    """Appwrite Cloud Function entry point."""

    # ── Environment ──
    APPWRITE_ENDPOINT = os.environ.get(
        'APPWRITE_FUNCTION_API_ENDPOINT', 'https://fra.cloud.appwrite.io/v1'
    )
    APPWRITE_PROJECT_ID = os.environ.get('APPWRITE_FUNCTION_PROJECT_ID')
    APPWRITE_API_KEY = os.environ.get('APPWRITE_API_KEY')

    BUCKET_ID = os.environ.get('BUCKET_ID', 'photos')
    DATABASE_ID = os.environ.get('DATABASE_ID', 'ivex_db')
    COLLECTION_ID = os.environ.get('COLLECTION_ID', 'results')

    # ⬇️ Set this to your Render.com ML server URL
    ML_SERVER_URL = os.environ.get('ML_SERVER_URL', '')

    context.log("IVEX — Function triggered (ML Server Proxy)")

    if not ML_SERVER_URL:
        context.error("ML_SERVER_URL environment variable is not set!")
        return context.res.json({"success": False, "error": "ML_SERVER_URL not configured"})

    # ── Parse event payload ──
    try:
        event_data = context.req.body
        if isinstance(event_data, str):
            event_data = json.loads(event_data)
    except Exception as e:
        context.error(f"Failed to parse event: {e}")
        return context.res.json({"success": False, "error": "Invalid event data"})

    file_id = event_data.get('$id') or event_data.get('fileId')
    bucket_id = event_data.get('bucketId', BUCKET_ID)

    if not file_id:
        context.error("No file ID in event")
        return context.res.json({"success": False, "error": "No file ID"})

    context.log(f"Processing file: {file_id}")

    # ── Initialize Appwrite ──
    client = Client()
    client.set_endpoint(APPWRITE_ENDPOINT)
    client.set_project(APPWRITE_PROJECT_ID)
    client.set_key(APPWRITE_API_KEY)

    storage = Storage(client)
    databases = Databases(client)

    doc_id = None

    try:
        # ═══════════════════════════════════
        # STEP 1: Download image from Storage
        # ═══════════════════════════════════
        context.log("Step 1/4: Downloading image...")

        image_url = (
            f"{APPWRITE_ENDPOINT}/storage/buckets/{bucket_id}"
            f"/files/{file_id}/view?project={APPWRITE_PROJECT_ID}"
        )
        resp = requests.get(image_url, timeout=30)
        if resp.status_code != 200:
            raise Exception(f"Download failed: HTTP {resp.status_code}")

        image_bytes = resp.content
        image_b64 = base64.b64encode(image_bytes).decode('utf-8')
        context.log(f"Downloaded: {len(image_bytes)} bytes")

        # ═══════════════════════════════════
        # STEP 2: Create initial DB entry
        # ═══════════════════════════════════
        context.log("Step 2/4: Creating database entry...")

        initial_doc = databases.create_document(
            database_id=DATABASE_ID,
            collection_id=COLLECTION_ID,
            document_id=ID.unique(),
            data={
                'original_file_id': file_id,
                'status': 'processing',
                'face_shape': '',
                'advice_text': '',
                'generated_image_url': '',
                'created_at': int(time.time() * 1000),
            }
        )
        doc_id = initial_doc['$id']
        context.log(f"Created document: {doc_id}")

        # ═══════════════════════════════════
        # STEP 3: Send to ML Server
        # ═══════════════════════════════════
        context.log("Step 3/4: Sending to ML server...")

        ml_response = requests.post(
            f"{ML_SERVER_URL}/analyze",
            json={"image": image_b64},
            timeout=90,
        )

        if ml_response.status_code != 200:
            raise Exception(f"ML server error: HTTP {ml_response.status_code}")

        result = ml_response.json()
        context.log(f"ML server response: {json.dumps(result)[:300]}")

        if not result.get('success'):
            error_msg = result.get('error', 'Analysis failed')
            databases.update_document(
                database_id=DATABASE_ID,
                collection_id=COLLECTION_ID,
                document_id=doc_id,
                data={'status': 'error', 'advice_text': error_msg},
            )
            return context.res.json({"success": False, "error": error_msg})

        # ═══════════════════════════════════
        # STEP 4: Save results to DB
        # ═══════════════════════════════════
        context.log("Step 4/4: Saving results...")

        face_shape = result['faceShape']

        # Build structured JSON (same format Flutter expects)
        structured_result = json.dumps({
            "confidence": result.get('confidence', 0),
            "measurements": result.get('measurements', {}),
            "recommendations": result.get('recommendations', {}),
            "advice": result.get('advice', ''),
        })

        # Generate Pollinations image URL
        generated_image_url = _generate_pollinations_url(face_shape, image_url)

        databases.update_document(
            database_id=DATABASE_ID,
            collection_id=COLLECTION_ID,
            document_id=doc_id,
            data={
                'status': 'completed',
                'face_shape': face_shape,
                'advice_text': structured_result,
                'generated_image_url': generated_image_url,
            },
        )

        context.log(f"Done! Shape: {face_shape.upper()}")

        return context.res.json({
            "success": True,
            "document_id": doc_id,
            "faceShape": face_shape,
        })

    except Exception as e:
        context.error(f"Error: {e}")
        if doc_id:
            try:
                databases.update_document(
                    database_id=DATABASE_ID,
                    collection_id=COLLECTION_ID,
                    document_id=doc_id,
                    data={'status': 'error', 'advice_text': str(e)},
                )
            except Exception:
                pass
        return context.res.json({"success": False, "error": str(e)})


def _generate_pollinations_url(face_shape, original_image_url):
    """Generate a Pollinations.ai image URL for the detected face shape."""
    style_map = {
        "round": "tall pompadour with undercut sides, textured volume on top",
        "oval": "classic textured crop with tapered sides, natural volume",
        "square": "textured messy fringe with soft layers, medium length on top",
        "heart": "side swept bangs with medium texture, soft layers around chin",
        "diamond": "fringe with textured top, tapered sides, chin-level layers",
        "oblong": "side swept bangs with layered sides, medium volume all around",
    }

    style = style_map.get(face_shape.lower(), "modern stylish haircut")
    prompt = f"photorealistic, man with {style}, 8k, highly detailed hair texture"

    encoded_prompt = urllib.parse.quote(prompt)
    encoded_image = urllib.parse.quote(original_image_url)
    seed = random.randint(1, 999999)

    return (
        f"https://pollinations.ai/p/{encoded_prompt}"
        f"?width=512&height=512&seed={seed}"
        f"&model=flux&nologo=true"
        f"&image={encoded_image}&strength=0.7"
    )

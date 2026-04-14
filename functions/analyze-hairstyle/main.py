"""
IVEX Hairstyle Consulting - Appwrite Cloud Function
Analyzes face shape using Google Gemini and generates hairstyle suggestions using OpenRouter
"""

import os
import json
import base64
import time
import requests
from appwrite.client import Client
from appwrite.services.storage import Storage
from appwrite.services.databases import Databases
import google.generativeai as genai


def main(context):
    """
    Main entry point for the Appwrite Function.
    Triggered by storage.buckets.*.files.*.create events.
    """
    
    # Initialize environment variables
    APPWRITE_ENDPOINT = os.environ.get('APPWRITE_FUNCTION_API_ENDPOINT', 'https://fra.cloud.appwrite.io/v1')
    APPWRITE_PROJECT_ID = os.environ.get('APPWRITE_FUNCTION_PROJECT_ID')
    APPWRITE_API_KEY = os.environ.get('APPWRITE_API_KEY')
    GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
    OPENROUTER_API_KEY = os.environ.get('OPENROUTER_API_KEY')
    
    # Appwrite resource IDs
    BUCKET_ID = os.environ.get('BUCKET_ID', 'photos')
    DATABASE_ID = os.environ.get('DATABASE_ID', 'ivex_db')
    COLLECTION_ID = os.environ.get('COLLECTION_ID', 'results')
    
    context.log("IVEX Stylist Agent - Function triggered")
    
    # Parse the event payload
    try:
        event_data = context.req.body
        if isinstance(event_data, str):
            event_data = json.loads(event_data)
        
        context.log(f"Event data received: {json.dumps(event_data)[:500]}")
    except Exception as e:
        context.error(f"Failed to parse event data: {str(e)}")
        return context.res.json({"success": False, "error": "Invalid event data"})
    
    # Extract file information from the event
    file_id = event_data.get('$id') or event_data.get('fileId')
    bucket_id = event_data.get('bucketId', BUCKET_ID)
    
    if not file_id:
        context.error("No file ID found in event")
        return context.res.json({"success": False, "error": "No file ID in event"})
    
    context.log(f"Processing file: {file_id} from bucket: {bucket_id}")
    
    # Initialize Appwrite Client
    client = Client()
    client.set_endpoint(APPWRITE_ENDPOINT)
    client.set_project(APPWRITE_PROJECT_ID)
    client.set_key(APPWRITE_API_KEY)
    
    storage = Storage(client)
    databases = Databases(client)
    
    try:
        # Step 1: Download the uploaded image
        context.log("Step 1: Downloading uploaded image...")
        
        file_content = storage.get_file_download(bucket_id, file_id)
        image_base64 = base64.b64encode(file_content).decode('utf-8')
        
        context.log(f"Image downloaded successfully, size: {len(file_content)} bytes")
        
        # Step 2: Create initial database entry with "processing" status
        context.log("Step 2: Creating database entry...")
        
        initial_doc = databases.create_document(
            database_id=DATABASE_ID,
            collection_id=COLLECTION_ID,
            document_id='unique()',
            data={
                'original_file_id': file_id,
                'status': 'processing',
                'face_shape': '',
                'advice_text': '',
                'generated_image_url': '',
                'created_at': int(time.time() * 1000)
            }
        )
        
        doc_id = initial_doc['$id']
        context.log(f"Created document with ID: {doc_id}")
        
        # Step 3: Analyze face with Google Gemini
        context.log("Step 3: Analyzing face shape with Gemini...")
        
        face_analysis = analyze_face_with_gemini(
            image_base64, 
            GEMINI_API_KEY,
            context
        )
        
        context.log(f"Face analysis result: {json.dumps(face_analysis)}")
        
        # Step 4: Generate hairstyle image with OpenRouter
        context.log("Step 4: Generating hairstyle with OpenRouter...")
        
        generated_image_url = generate_hairstyle_with_openrouter(
            face_analysis.get('stable_diffusion_prompt', ''),
            OPENROUTER_API_KEY,
            context
        )
        
        context.log(f"Generated image URL: {generated_image_url}")
        
        # Step 5: Update database with results
        context.log("Step 5: Saving results to database...")
        
        databases.update_document(
            database_id=DATABASE_ID,
            collection_id=COLLECTION_ID,
            document_id=doc_id,
            data={
                'status': 'completed',
                'face_shape': face_analysis.get('face_shape', 'Unknown'),
                'advice_text': face_analysis.get('advice', 'Unable to generate advice'),
                'generated_image_url': generated_image_url
            }
        )
        
        context.log("IVEX Stylist Agent - Processing completed successfully!")
        
        return context.res.json({
            "success": True,
            "document_id": doc_id,
            "face_shape": face_analysis.get('face_shape'),
            "generated_image_url": generated_image_url
        })
        
    except Exception as e:
        context.error(f"Error processing image: {str(e)}")
        
        # Try to update doc with error status if we created one
        try:
            if 'doc_id' in locals():
                databases.update_document(
                    database_id=DATABASE_ID,
                    collection_id=COLLECTION_ID,
                    document_id=doc_id,
                    data={
                        'status': 'error',
                        'advice_text': f'Processing failed: {str(e)}'
                    }
                )
        except:
            pass
        
        return context.res.json({
            "success": False,
            "error": str(e)
        })


def analyze_face_with_gemini(image_base64: str, api_key: str, context) -> dict:
    """
    Analyze face shape using Google Gemini Vision API.
    Returns face shape and a prompt for hairstyle generation.
    """
    
    genai.configure(api_key=api_key)
    
    model = genai.GenerativeModel('gemini-1.5-flash')
    
    # Create the image part for Gemini
    image_part = {
        "mime_type": "image/jpeg",
        "data": image_base64
    }
    
    prompt = """You are an expert hair stylist and face shape analyst. Analyze this person's face and provide hairstyle recommendations.

Analyze the face in this image and respond with ONLY a valid JSON object (no markdown, no code blocks, just pure JSON):

{
    "face_shape": "The detected face shape (oval, round, square, heart, oblong, diamond, or triangle)",
    "face_shape_description": "Brief description of why this face shape was detected",
    "stable_diffusion_prompt": "A detailed prompt to generate a modern, stylish men's hairstyle that suits this face shape. Include specific hairstyle name, texture, length, and styling details. The prompt should create a realistic portrait.",
    "advice": "Personalized barber advice for this face shape including: recommended hairstyles, what to avoid, styling tips, and how to communicate with their barber. Make it detailed and actionable."
}

Focus on men's hairstyles. Be specific and professional in your recommendations. The stable_diffusion_prompt should create a photorealistic portrait image showing just the hairstyle recommendation."""

    try:
        response = model.generate_content([prompt, image_part])
        response_text = response.text.strip()
        
        # Clean up the response - remove markdown code blocks if present
        if response_text.startswith('```'):
            lines = response_text.split('\n')
            response_text = '\n'.join(lines[1:-1])
        if response_text.startswith('json'):
            response_text = response_text[4:].strip()
        
        context.log(f"Gemini raw response: {response_text[:500]}")
        
        result = json.loads(response_text)
        return result
        
    except json.JSONDecodeError as e:
        context.error(f"Failed to parse Gemini response as JSON: {str(e)}")
        return {
            "face_shape": "Unknown",
            "stable_diffusion_prompt": "Professional headshot of a handsome man with a modern stylish haircut, studio lighting, high quality portrait photography",
            "advice": "Unable to analyze face shape. Please try again with a clearer front-facing photo."
        }
    except Exception as e:
        context.error(f"Gemini API error: {str(e)}")
        raise


def generate_hairstyle_with_openrouter(prompt: str, api_key: str, context) -> str:
    """
    Generate a hairstyle image using OpenRouter API.
    Uses chat completions with modalities: ["image", "text"] for image generation.
    Returns the URL of the generated image.
    """
    
    if not prompt:
        prompt = "Professional headshot of a handsome man with a modern stylish haircut, studio lighting, high quality portrait photography"
    
    # Enhance the prompt for better results
    enhanced_prompt = f"Generate a photorealistic portrait image: {prompt}, professional studio photography, soft lighting, 8k resolution, highly detailed"
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://ivex.app",  # Required by OpenRouter
        "X-Title": "IVEX Hairstyle Consulting"  # Optional, shows in OpenRouter dashboard
    }
    
    # OpenRouter chat completions with image modality
    # Using riverflow-v2-max-preview model for image generation
    payload = {
        "model": "sourceful/riverflow-v2-max-preview",
        "messages": [
            {
                "role": "user",
                "content": enhanced_prompt
            }
        ],
        "modalities": ["image", "text"]
    }
    
    context.log(f"Calling OpenRouter API with prompt: {enhanced_prompt[:200]}...")
    
    try:
        # Call OpenRouter's chat completions endpoint
        response = requests.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers=headers,
            json=payload,
            timeout=120
        )
        
        context.log(f"OpenRouter response status: {response.status_code}")
        
        if response.status_code != 200:
            error_text = response.text
            context.error(f"OpenRouter API error: {error_text}")
            
            # Fallback: Try alternative model
            context.log("Trying fallback model (black-forest-labs/flux-schnell)...")
            payload["model"] = "black-forest-labs/flux-schnell"
            
            response = requests.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers=headers,
                json=payload,
                timeout=120
            )
        
        response.raise_for_status()
        result = response.json()
        
        context.log(f"OpenRouter response: {json.dumps(result)[:1000]}")
        
        # Extract the image URL from the response
        # Response format: result.choices[0].message.images[].image_url.url
        if 'choices' in result and len(result['choices']) > 0:
            message = result['choices'][0].get('message', {})
            
            # Check for images array
            if 'images' in message and len(message['images']) > 0:
                image_data = message['images'][0]
                if 'image_url' in image_data and 'url' in image_data['image_url']:
                    image_url = image_data['image_url']['url']
                    context.log(f"Extracted image URL: {image_url[:100]}...")
                    return image_url
            
            # Alternative: Check content for image URL
            content = message.get('content', '')
            if content and ('http' in content or 'data:image' in content):
                # Try to extract URL from content
                import re
                url_pattern = r'https?://[^\s<>"{}|\\^`\[\]]+'
                urls = re.findall(url_pattern, content)
                if urls:
                    context.log(f"Extracted URL from content: {urls[0][:100]}...")
                    return urls[0]
        
        context.error("No image found in OpenRouter response")
        raise Exception("No image URL in OpenRouter response")
            
    except requests.exceptions.RequestException as e:
        context.error(f"OpenRouter API request failed: {str(e)}")
        raise
        
    except Exception as e:
        context.error(f"OpenRouter generation error: {str(e)}")
        raise

# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

from firebase_functions import https_fn, options
from firebase_admin import initialize_app, storage # Import storage
from google.cloud import storage as gcs # Import Google Cloud Storage client library
from openai import OpenAI
import base64
import json
import os
import re # Import regex for parsing URI
from pydantic import BaseModel, Field, ValidationError
from typing import List, Union
import traceback # Keep for error logging

# Initialize Firebase Admin SDK
initialize_app()

# --- Pydantic Models for Structured Output (Keep these) ---
class ReceiptItem(BaseModel):
    item: str
    quantity: Union[int, float]
    price: float

class ReceiptData(BaseModel):
    items: List[ReceiptItem]
    subtotal: float

# Initialize OpenAI client (moved inside function)
# client = OpenAI()

@https_fn.on_request(
    cors=options.CorsOptions(cors_origins="*", cors_methods=["post"]),
    secrets=["OPENAI_API_KEY"],
    memory=1024,
    timeout_sec=120
)
def parse_receipt(req: https_fn.Request) -> https_fn.Response:
    """Receives a GCS URI via POST, downloads image, parses with OpenAI, returns parsed data."""
    print("--- FULL FUNCTION HANDLER ENTERED ---")

    # --- Client Initialization --- (Moved inside try block for clarity)
    try:
        print("Attempting to retrieve OpenAI API key...")
        openai_api_key = os.environ.get('OPENAI_API_KEY')
        if not openai_api_key:
            raise ValueError("OpenAI API key secret ('OPENAI_API_KEY') not found.")
        client = OpenAI(api_key=openai_api_key)
        print("OpenAI client initialized.")

        storage_client = gcs.Client()
        print("Google Cloud Storage client initialized.")

    except Exception as e:
        print(f"ERROR during client setup: {e}")
        # Return error in consistent format
        return {
            "error": {"message": f"Internal Server Error: Failed to initialize clients - {e}", "status": 500}
        }, 500

    # --- Request Validation --- (Moved inside main try block)
    if req.method != "POST":
        print(f"ERROR: Method {req.method} not allowed.")
        return {
            "error": {"message": f"Method {req.method} not allowed.", "status": 405}
        }, 405

    # --- Main Processing Logic --- 
    try:
        print("Attempting to parse request JSON...")
        request_json = req.get_json(silent=True)
        print(f"Request JSON received: {request_json}")

        # ** CORRECTLY get imageUri from within 'data' wrapper **
        if not (request_json and isinstance(request_json, dict) and 'data' in request_json and isinstance(request_json['data'], dict) and 'imageUri' in request_json['data']):
            print(f"ERROR: Invalid request structure. Missing 'data' wrapper or 'imageUri' inside it. Received: {request_json}")
            raise ValueError("Invalid request: Missing 'data.imageUri' in JSON body.")

        image_uri = request_json['data']['imageUri']
        print(f"Received image URI: {image_uri}")

        # Validate and parse the gs:// URI
        match = re.match(r"gs://([^/]+)/(.+)", image_uri)
        if not match:
            print(f"ERROR: Invalid gs:// URI format: {image_uri}")
            raise ValueError("Invalid request: 'imageUri' must be a valid gs:// URI.")

        bucket_name = match.group(1)
        blob_name = match.group(2)
        print(f"Parsed URI: Bucket='{bucket_name}', Blob='{blob_name}'")

        # Download image from Cloud Storage
        base64_image = None
        try:
            bucket = storage_client.bucket(bucket_name)
            blob = bucket.blob(blob_name)
            print(f"Attempting to download blob: {blob_name} from bucket: {bucket_name}")
            image_bytes = blob.download_as_bytes()
            print(f"Successfully downloaded {len(image_bytes)} bytes.")
            base64_image = base64.b64encode(image_bytes).decode('utf-8')
            print("Image successfully encoded to base64.")
        except Exception as storage_error:
            print(f"ERROR downloading/encoding image from Storage: {storage_error}")
            # Re-raise to be caught by the outer try/except block
            raise Exception(f"Failed to retrieve image from Storage URI '{image_uri}': {storage_error}")

        if not base64_image:
             raise Exception("Internal error: Failed to process image after download.")

        # --- Call OpenAI API ---
        print("Sending request to OpenAI API...")
        response = client.chat.completions.create(
            model="gpt-4o",
            response_format={ "type": "json_object" },
            messages=[{
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": '''Parse the image and generate a receipt. Return a JSON object with the following structure:
                            {
                                "items": [
                                {
                                    "item": "string",
                                    "quantity": number,
                                    "price": number
                                }
                                ],
                                "subtotal": number,
                            }

                            Instructions:
                            - First, accurately transcribe every item and its listed price exactly as shown on the receipt, before performing any calculations or transformations. Do not assume or infer numbers — copy the listed amount first. Only after verifying transcription, adjust for quantities.
                            - Sometimes, items may have add-ons or modifiers in the receipt.
                            - Use your intuition to roll up the add-ons into the parent item and sum the prices.
                            - If an item or line has its own price listed to the far right of it, it must be treated as a separate line item in the JSON, even if it appears visually indented, grouped, or described as part of a larger item. Do not assume bundling unless there is no separate price.
                            - MAKE SURE the price is the individual price for the item and the quantity is accurate based on the receipt. (ex. If the receipt says Quantity of 2 and price is $10, then the price of the item to provide is $5, not $10)
                            - MAKE SURE all items, quantities, and prices are present and accurate in the json'''
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            }
                        },
                    ],
                }],
            max_tokens=1000,
        )
        print("Received response from OpenAI API.")

        # --- Process OpenAI Response ---
        parsed_content = response.choices[0].message.content
        try:
            receipt_data = ReceiptData.model_validate_json(parsed_content)
            print("Successfully validated OpenAI response against Pydantic model.")
            
            # Return the response properly wrapped in a data object
            # Firebase Functions handles the JSON conversion automatically
            return {
                "data": receipt_data.model_dump()
            }

        except (ValidationError, json.JSONDecodeError) as validation_error:
            print(f"ERROR processing OpenAI response: {validation_error}")
            print(f"Raw OpenAI response: {parsed_content}")
            # Re-raise to be caught by the outer try/except block
            raise Exception(f"Failed to validate/decode OpenAI response: {validation_error}")

    # --- General Error Handling --- 
    except Exception as e:
        print(f"ERROR processing request: {e}")
        traceback.print_exc()
        # Use the same direct dictionary return format for errors
        # The Firebase Functions SDK will handle the JSON conversion
        status_code = 400 if isinstance(e, ValueError) else 500
        # Return error as a properly formatted dictionary
        return {
            "error": {"message": f"Internal Server Error: {e}", "status": status_code}
        }, status_code

# You might want to remove or comment out the example function if you keep it.
# @https_fn.on_request()
# def on_request_example(req: https_fn.Request) -> https_fn.Response:
#     return https_fn.Response("Hello world!")
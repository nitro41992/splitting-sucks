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
from typing import List, Union, Dict, Any, Optional
import traceback # Keep for error logging
from config_helper import get_dynamic_config # Import the config helper

# Initialize Firebase Admin SDK
initialize_app()

# --- Pydantic Models for Structured Output (Keep these) ---
class ReceiptItem(BaseModel):
    item: str
    quantity: int
    price: float

class ReceiptData(BaseModel):
    items: List[ReceiptItem]
    subtotal: float

# --- Models for Assignment Result ---
class Order(BaseModel):
    person: str
    item: str
    price: float
    quantity: int

class SharedItem(BaseModel):
    item: str
    price: float
    quantity: int
    people: List[str]

class Person(BaseModel):
    name: str

class UnassignedItem(BaseModel):
    item: str
    price: float
    quantity: int

class AssignmentResult(BaseModel):
    orders: List[Order]
    shared_items: List[SharedItem]
    people: List[Person]
    unassigned_items: Optional[List[UnassignedItem]] = None

# --- Model for Transcription Result ---
class TranscriptionResult(BaseModel):
    text: str

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

        # Fetch dynamic configuration
        config = get_dynamic_config('parse_receipt')
        
        # Set defaults if config couldn't be fetched
        default_prompt = '''Parse the image and generate a receipts.

        **Instructions:**
        - Sometimes, items may have add-ons or modifiers in the receipt. 
            - Use your intution to roll up the add-ons into the parent item and sum the prices.
        - MAKE SURE the price is the individiual price for the item and the quantity is accurate based on the receipt. (ex. If the receipt says Quantity of 2 and price is $10, then the price of the item to provide is $5, not $10)
        - MAKE SURE all items, quantities, and prices are present and accurate in the json

        You should return a JSON object that contains the following keys:
        - items: A list of dictionaries representing individual items. Each dictionary should have the following keys:
            - item: The name of the item.
            - quantity: The quantity of the item.
            - price: The price of one unit of the item.
        - subtotal: The subtotal amount.

        Instructions:
        - First, accurately transcribe every item and its listed price exactly as shown on the receipt, before performing any calculations or transformations. Do not assume or infer numbers — copy the listed amount first. Only after verifying transcription, adjust for quantities.
        - Sometimes, items may have add-ons or modifiers in the receipt.
        - Use your intuition to roll up the add-ons into the parent item and sum the prices.
        - If an item or line has its own price listed to the far right of it, it must be treated as a separate line item in the JSON, even if it appears visually indented, grouped, or described as part of a larger item. Do not assume bundling unless there is no separate price.
        - MAKE SURE the price is the individual price for the item and the quantity is accurate based on the receipt. (ex. If the receipt says Quantity of 2 and price is $10, then the price of the item to provide is $5, not $10)
        - MAKE SURE all items, quantities, and prices are present and accurate in the json'''
        
        default_model = "gpt-4.1"
        default_max_tokens = 32768
        
        if config:
            prompt = config.get('prompt') or default_prompt
            model = config.get('model') or default_model
            max_tokens = config.get('max_tokens') or default_max_tokens
            
            # Enhanced logging
            sources = config.get('sources', {})
            print(f"Configuration for parse_receipt:")
            print(f"  - prompt: using value from {sources.get('prompt', 'default')}")
            print(f"  - model: {model} (from {sources.get('model', 'default')})")
            print(f"  - max_tokens: {max_tokens} (from {sources.get('max_tokens', 'default')})")
        else:
            prompt = default_prompt
            model = default_model
            max_tokens = default_max_tokens
            print("Using ALL default configurations (dynamic config not available)")

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

        # Validate request structure
        if not (request_json and isinstance(request_json, dict)):
            print(f"ERROR: Invalid request structure. Not a valid JSON object. Received: {request_json}")
            raise ValueError("Invalid request: Not a valid JSON object.")

        # The Firebase SDK automatically wraps parameters in a 'data' object
        data = request_json.get('data', {})
        
        # Check for imageUri in data
        if not (isinstance(data, dict) and 'imageUri' in data):
            print(f"ERROR: Invalid data structure. Missing 'imageUri' field. Received: {data}")
            raise ValueError("Invalid request: 'data' must contain 'imageUri' field.")

        image_uri = data['imageUri']
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
        response = client.beta.chat.completions.parse(
            model=model,
            response_format=ReceiptData,
            messages=[{
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": prompt
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            }
                        },
                    ],
                }],
            max_tokens=max_tokens,
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

@https_fn.on_request(
    cors=options.CorsOptions(cors_origins="*", cors_methods=["post"]),
    secrets=["OPENAI_API_KEY"],
    memory=1024,
    timeout_sec=120
)
def assign_people_to_items(req: https_fn.Request) -> https_fn.Response:
    """Assigns people to receipt items based on voice transcription."""
    print("--- ASSIGN PEOPLE TO ITEMS FUNCTION ENTERED ---")

    # --- Client Initialization ---
    try:
        print("Attempting to retrieve OpenAI API key...")
        openai_api_key = os.environ.get('OPENAI_API_KEY')
        if not openai_api_key:
            raise ValueError("OpenAI API key secret ('OPENAI_API_KEY') not found.")
        client = OpenAI(api_key=openai_api_key)
        print("OpenAI client initialized.")

        # Fetch dynamic configuration
        config = get_dynamic_config('assign_people_to_items')
        
        # Set defaults if config couldn't be fetched
        default_system_prompt = '''You are a helpful assistant that assigns items from a receipt to people based on voice instructions.
        Analyze the voice transcription and receipt items to determine who ordered what.
        Each item in the receipt items list has a numeric 'id'. Use these IDs to refer to items when possible, especially if the transcription mentions numbers.
        
        Pay close attention to:
        1. Include ALL people mentioned in the transcription
        2. Make sure all items are assigned to someone, marked as shared, or added to the unassigned_items array. Its important to include all items.
        3. Ensure quantities and prices match the receipt, providing a positive integer for quantity.
        4. If not every instance of an item is mentioned in the transcription, make sure to add the item to the unassigned_items array
        5. If numeric references to items are provided, use the provided numeric IDs to reference items when the transcription includes numbers that seem to correspond to items.'''
        
        default_model = "gpt-4.1"
        default_max_tokens = 32768
        
        if config:
            system_prompt = config.get('prompt') or default_system_prompt
            model = config.get('model') or default_model
            max_tokens = config.get('max_tokens') or default_max_tokens
            
            # Enhanced logging
            sources = config.get('sources', {})
            print(f"Configuration for assign_people_to_items:")
            print(f"  - prompt: using value from {sources.get('prompt', 'default')}")
            print(f"  - model: {model} (from {sources.get('model', 'default')})")
            print(f"  - max_tokens: {max_tokens} (from {sources.get('max_tokens', 'default')})")
        else:
            system_prompt = default_system_prompt
            model = default_model
            max_tokens = default_max_tokens
            print("Using ALL default configurations (dynamic config not available)")

    except Exception as e:
        print(f"ERROR during client setup: {e}")
        return {
            "error": {"message": f"Internal Server Error: Failed to initialize clients - {e}", "status": 500}
        }, 500

    # --- Request Validation ---
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

        # Validate request structure
        if not (request_json and isinstance(request_json, dict)):
            print(f"ERROR: Invalid request structure. Not a valid JSON object. Received: {request_json}")
            raise ValueError("Invalid request: Not a valid JSON object.")

        # The Firebase SDK automatically wraps parameters in a 'data' object
        data = request_json.get('data', {})
        
        # Check for required fields in data
        if not (isinstance(data, dict) and 'transcription' in data and 'receipt' in data):
            print(f"ERROR: Invalid data structure. Missing required fields. Received: {data}")
            raise ValueError("Invalid request: 'data' must contain 'transcription' and 'receipt' fields.")

        transcription = data['transcription']
        receipt = data['receipt']
        
        print(f"Received transcription: {transcription}")
        print(f"Received receipt data: {receipt}")

        # Call OpenAI API with dynamic configuration
        print("Sending request to OpenAI API...")
        response = client.beta.chat.completions.parse(
            model=model,
            response_format=AssignmentResult,
            messages=[
                {
                    "role": "system",
                    "content": system_prompt
                },
                {
                    "role": "user",
                    "content": f"Voice transcription: {transcription}\nReceipt items: {json.dumps(receipt)}"
                }
            ],
            max_tokens=max_tokens,
        )
        
        # --- Process OpenAI Response ---
        parsed_content = response.choices[0].message.content
        try:
            assignment_result = AssignmentResult.model_validate_json(parsed_content)
            print("Successfully validated OpenAI response against Pydantic model.")
            
            # Return the response properly wrapped in a data object
            return {
                "data": assignment_result.model_dump()
            }

        except (ValidationError, json.JSONDecodeError) as validation_error:
            print(f"ERROR processing OpenAI response: {validation_error}")
            print(f"Raw OpenAI response: {parsed_content}")
            raise Exception(f"Failed to validate/decode OpenAI response: {validation_error}")

    # --- General Error Handling ---
    except Exception as e:
        print(f"ERROR processing request: {e}")
        traceback.print_exc()
        status_code = 400 if isinstance(e, ValueError) else 500
        return {
            "error": {"message": f"Internal Server Error: {e}", "status": status_code}
        }, status_code

@https_fn.on_request(
    cors=options.CorsOptions(cors_origins="*", cors_methods=["post"]),
    secrets=["OPENAI_API_KEY"],
    memory=1024,
    timeout_sec=120
)
def transcribe_audio(req: https_fn.Request) -> https_fn.Response:
    """Transcribes audio using OpenAI's Whisper API."""
    print("--- TRANSCRIBE AUDIO FUNCTION ENTERED ---")

    # --- Client Initialization ---
    try:
        print("Attempting to retrieve OpenAI API key...")
        openai_api_key = os.environ.get('OPENAI_API_KEY')
        if not openai_api_key:
            raise ValueError("OpenAI API key secret ('OPENAI_API_KEY') not found.")
        client = OpenAI(api_key=openai_api_key)
        print("OpenAI client initialized.")

        # Initialize Storage client
        storage_client = gcs.Client()
        print("Google Cloud Storage client initialized.")

        # Fetch dynamic configuration
        config = get_dynamic_config('transcribe_audio')
        
        # Set defaults if config couldn't be fetched
        default_model = "whisper-1"
        
        if config:
            model = config.get('model') or default_model
            
            # Enhanced logging
            sources = config.get('sources', {})
            print(f"Configuration for transcribe_audio:")
            print(f"  - model: {model} (from {sources.get('model', 'default')})")
        else:
            model = default_model
            print("Using default configuration: model=whisper-1 (dynamic config not available)")

    except Exception as e:
        print(f"ERROR during client setup: {e}")
        return {
            "error": {"message": f"Internal Server Error: Failed to initialize clients - {e}", "status": 500}
        }, 500

    # --- Request Validation ---
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

        # Validate request structure
        if not (request_json and isinstance(request_json, dict)):
            print(f"ERROR: Invalid request structure. Not a valid JSON object. Received: {request_json}")
            raise ValueError("Invalid request: Not a valid JSON object.")

        # The Firebase SDK automatically wraps parameters in a 'data' object
        data = request_json.get('data', {})
        
        # Check for audio URI directly in data
        if not (isinstance(data, dict) and 'audioUri' in data):
            print(f"ERROR: Invalid data structure. Missing 'audioUri' field. Received: {data}")
            raise ValueError("Invalid request: 'data' must contain 'audioUri' field.")

        audio_uri = data['audioUri']
        print(f"Received audio URI: {audio_uri}")

        # Validate and parse the gs:// URI
        match = re.match(r"gs://([^/]+)/(.+)", audio_uri)
        if not match:
            print(f"ERROR: Invalid gs:// URI format: {audio_uri}")
            raise ValueError("Invalid request: 'audioUri' must be a valid gs:// URI.")

        bucket_name = match.group(1)
        blob_name = match.group(2)
        print(f"Parsed URI: Bucket='{bucket_name}', Blob='{blob_name}'")

        # Download audio from Cloud Storage
        audio_bytes = None
        try:
            bucket = storage_client.bucket(bucket_name)
            blob = bucket.blob(blob_name)
            print(f"Attempting to download blob: {blob_name} from bucket: {bucket_name}")
            audio_bytes = blob.download_as_bytes()
            print(f"Successfully downloaded {len(audio_bytes)} bytes of audio.")
        except Exception as storage_error:
            print(f"ERROR downloading audio from Storage: {storage_error}")
            raise Exception(f"Failed to retrieve audio from Storage URI '{audio_uri}': {storage_error}")

        if not audio_bytes:
            raise Exception("Internal error: Failed to process audio after download.")

        # Process the audio file
        try:
            # Create a temporary file for the audio
            import tempfile
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=True) as temp_audio_file:
                temp_audio_file.write(audio_bytes)
                temp_audio_file.flush()
                
                # Call OpenAI Whisper API with dynamic model
                with open(temp_audio_file.name, 'rb') as audio_file:
                    transcription = client.audio.transcriptions.create(
                        model=model,
                        file=audio_file
                    )
            
            print(f"Received transcription: {transcription.text}")
            
            # Return transcription result
            return {
                "data": {
                    "text": transcription.text
                }
            }

        except Exception as e:
            print(f"ERROR processing audio: {e}")
            traceback.print_exc()
            status_code = 400 if isinstance(e, ValueError) else 500
            return {
                "error": {"message": f"Internal Server Error: {e}", "status": status_code}
            }, status_code

    # --- General Error Handling ---
    except Exception as e:
        print(f"ERROR processing request: {e}")
        traceback.print_exc()
        status_code = 400 if isinstance(e, ValueError) else 500
        return {
            "error": {"message": f"Internal Server Error: {e}", "status": status_code}
        }, status_code

# You might want to remove or comment out the example function if you keep it.
# @https_fn.on_request()
# def on_request_example(req: https_fn.Request) -> https_fn.Response:
#     return https_fn.Response("Hello world!")
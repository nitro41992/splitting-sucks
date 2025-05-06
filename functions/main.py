# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

from firebase_functions import https_fn, options
from firebase_admin import initialize_app, storage # Import storage
from google.cloud import storage as gcs # Import Google Cloud Storage client library
from openai import OpenAI
# Import the two libraries with distinct aliases
from google import genai as genai_legacy # Older library for parse/assign
import google.generativeai as genai_new # Newer library for transcribe
# Keep instructor for OpenAI
import instructor 
import base64
import json
import os
import re # Import regex for parsing URI
import tempfile # Needed for downloading files
import mimetypes # Needed for Gemini file uploads
# Import types from both libraries with distinct aliases
from google.genai import types as genai_legacy_types # For legacy client
from google.generativeai import types as genai_new_types # For newer client (if needed)
from pydantic import BaseModel, Field, ValidationError
from typing import List, Union, Dict, Any, Optional
import traceback # Keep for error logging
from config_helper import get_dynamic_config # Import the config helper

# Initialize Firebase Admin SDK
initialize_app()

# --- Pydantic Models (Keep as is) ---
class ReceiptItem(BaseModel):
    item: str
    quantity: int
    price: float

class ReceiptData(BaseModel):
    items: List[ReceiptItem]
    subtotal: float

class AssignedItemRef(BaseModel): # Updated Assignment Model for simplicity
    id: int
    quantity: int

class PersonAssignment(BaseModel):
    person_name: str
    items: List[AssignedItemRef]

class AssignmentResult(BaseModel):
    person_assignments: List[PersonAssignment] # List of person assignments instead of Dict
    shared_items: List[AssignedItemRef]
    unassigned_items: List[AssignedItemRef]
    # Removed people list - can be derived from assignments keys

class TranscriptionResult(BaseModel):
    text: str

# --- New Pydantic Models for Redesigned Receipt Data Structure ---
class ItemDetail(BaseModel):
    name: str
    quantity: int
    price: float

class SharedItemDetail(BaseModel):
    name: str
    quantity: int
    price: float
    people: List[str]

class AssignPeopleToItems(BaseModel):
    assignments: Dict[str, List[ItemDetail]] = Field(default_factory=dict)
    shared_items: List[SharedItemDetail] = Field(default_factory=list)
    unassigned_items: List[ItemDetail] = Field(default_factory=list)

# --- Helper Functions ---

def _download_blob_to_tempfile(bucket_name, blob_name):
    """Downloads a blob to a temporary file and returns its path."""
    storage_client = gcs.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(blob_name)

    # Extract the file extension from the blob name
    _, extension = os.path.splitext(blob_name)

    # Create a temporary file descriptor, get its path, and close the descriptor
    # Suffix ensures the temp file has the correct extension for mimetypes
    temp_fd, temp_local_filename = tempfile.mkstemp(suffix=extension)
    os.close(temp_fd) # Close the file descriptor, we only need the path

    print(f"Downloading gs://{bucket_name}/{blob_name} to {temp_local_filename}")
    blob.download_to_filename(temp_local_filename)
    print("Download complete.")
    return temp_local_filename

def _validate_data(data: dict, model: BaseModel):
    """Validates dictionary data against a Pydantic model."""
    try:
        validated_data = model.model_validate(data)
        return validated_data
    except ValidationError as e:
        print(f"Pydantic validation failed: {e}")
        print(f"Data being validated: {data}")
        raise ValueError(f"Output validation failed: {e}") from e

def _parse_json_from_response(text: str, model: BaseModel):
    """Attempts to parse JSON from text, handling potential markdown/text noise."""
    try:
        # Basic cleanup: remove potential markdown code blocks
        text = re.sub(r"^```json\n?", "", text.strip(), flags=re.MULTILINE)
        text = re.sub(r"\n?```$", "", text.strip(), flags=re.MULTILINE)
        data = json.loads(text)
        return _validate_data(data, model)
    except json.JSONDecodeError as e:
        print(f"Failed to decode JSON: {e}")
        print(f"Raw text received: {text}")
        raise ValueError(f"Response was not valid JSON: {e}") from e
    except Exception as e: # Catch potential validation errors too
        raise e # Re-raise validation or other errors

# --- Cloud Functions ---

@https_fn.on_request(
    cors=options.CorsOptions(cors_origins="*", cors_methods=["post"]),
    secrets=["OPENAI_API_KEY", "GOOGLE_API_KEY"], # Added GOOGLE_API_KEY
    memory=options.MemoryOption.GB_1, # Use enum for memory
    timeout_sec=120
)
def parse_receipt(req: https_fn.Request) -> https_fn.Response:
    """Receives GCS URI, gets config, calls selected AI provider (OpenAI/Gemini) for parsing, returns data."""
    print("--- PARSE RECEIPT FUNCTION HANDLER ENTERED ---")
    openai_client = None # Will hold the *patched* client
    gemini_model = None

    try:
        # --- Configuration and Client Setup ---
        print("Fetching dynamic configuration for parse_receipt...")
        config = get_dynamic_config('parse_receipt')
        if not config:
            raise ValueError("Failed to retrieve dynamic configuration.")

        provider = config.get('provider_name')
        prompt = config.get('prompt')
        model_name = config.get('model')
        # max_tokens = config.get('max_tokens') # Less relevant for Gemini JSON mode, OpenAI uses internally

        print(f"Using Provider: {provider}, Model: {model_name}")
        if not provider or not model_name or not prompt:
             raise ValueError(f"Incomplete configuration received: Provider='{provider}', Model='{model_name}', Prompt exists='{prompt is not None}'")

        if provider == 'openai':
            openai_api_key = os.environ.get('OPENAI_API_KEY')
            if not openai_api_key:
                raise ValueError("OpenAI API key secret ('OPENAI_API_KEY') not found.")
            # Patch the client with instructor
            openai_client = instructor.from_openai(OpenAI(api_key=openai_api_key))
            print("OpenAI client initialized and patched with Instructor.")
        elif provider == 'gemini':
            google_api_key = os.environ.get('GOOGLE_API_KEY')
            if not google_api_key:
                 raise ValueError("Google API key secret ('GOOGLE_API_KEY') not found.")
            # Use genai_legacy.Client here
            client = genai_legacy.Client(api_key=google_api_key)
            gemini_model_name = model_name # Store the configured model name
            print(f"Gemini legacy client initialized. Will use model: {gemini_model_name}")
        else:
            raise ValueError(f"Unsupported provider selected: {provider}")

        # --- Request Validation ---
        if req.method != "POST":
            raise ValueError(f"Method {req.method} not allowed.")

        print("Attempting to parse request JSON...")
        request_json = req.get_json(silent=True)
        if not request_json:
             raise ValueError("Invalid request: No JSON body found.")
        data = request_json.get('data', {})
        image_uri = data.get('imageUri')
        if not image_uri:
            raise ValueError("Invalid request: 'data' must contain 'imageUri' field.")
        print(f"Received image URI: {image_uri}")

        match = re.match(r"gs://([^/]+)/(.+)", image_uri)
        if not match:
            raise ValueError("Invalid request: 'imageUri' must be a valid gs:// URI.")
        bucket_name, blob_name = match.groups()
        print(f"Parsed URI: Bucket='{bucket_name}', Blob='{blob_name}'")

        # --- Image Processing ---
        temp_image_path = None
        try:
            temp_image_path = _download_blob_to_tempfile(bucket_name, blob_name)
            mime_type, _ = mimetypes.guess_type(temp_image_path)
            if not mime_type or not mime_type.startswith("image/"):
                 raise ValueError(f"Downloaded file is not a recognized image type: {mime_type}")
            print(f"Image downloaded to {temp_image_path}, MIME type: {mime_type}")

            # --- Provider-Specific API Call ---
            receipt_data: ReceiptData = None

            if provider == 'openai':
                print("Sending request to OpenAI API via Instructor...")
                with open(temp_image_path, "rb") as image_file:
                    base64_image = base64.b64encode(image_file.read()).decode('utf-8')

                # Use instructor's response_model parameter
                # The response 'receipt_data' should be a validated ReceiptData object
                receipt_data = openai_client.chat.completions.create(
                    model=model_name,
                    response_model=ReceiptData, # Use instructor's response_model
                    messages=[{
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {"type": "image_url", "image_url": {"url": f"data:{mime_type};base64,{base64_image}"}}
                        ]
                    }],
                    # max_tokens is usually not needed when using response_model
                )
                print("Received and validated response from OpenAI via Instructor.")
                # No need for _parse_json_from_response here, instructor handles it.

            elif provider == 'gemini':
                print("Sending request to Gemini API...")
                # Read image bytes from temporary file
                with open(temp_image_path, "rb") as image_file:
                    image_bytes = image_file.read()
                print(f"Read {len(image_bytes)} bytes from image file.")

                # Ensure prompt is a string
                if not isinstance(prompt, str):
                    raise TypeError(f"Prompt must be a string, got: {type(prompt)}")

                # Create image part from bytes using legacy types
                image_part = genai_legacy_types.Part.from_bytes(
                    data=image_bytes,
                    mime_type=mime_type,
                )

                # Configure generation settings including schema and thinking budget using legacy types
                generation_config = genai_legacy_types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=ReceiptData, # Specify Pydantic model here
                    thinking_config=genai_legacy_types.ThinkingConfig(thinking_budget=8000)
                )

                # Send request using client.models.generate_content
                response = client.models.generate_content(
                    model=f'models/{gemini_model_name}', # Use the stored model name
                    contents=[prompt, image_part], # Send prompt text and image part
                    config=generation_config # Correct keyword: 'config'
                )

                print("Received response from Gemini API.")

                # Access the parsed object using response.parsed
                if hasattr(response, 'parsed') and response.parsed:
                    # Check if parsed is a list or single object based on schema (ReceiptData)
                    if isinstance(response.parsed, ReceiptData):
                        receipt_data = response.parsed # Use directly if it's a single object
                        print("Successfully retrieved parsed/validated Gemini response.")
                    # test.py example showed list[ReceiptData], handle that just in case
                    elif isinstance(response.parsed, list) and len(response.parsed) > 0 and isinstance(response.parsed[0], ReceiptData):
                         receipt_data = response.parsed[0] # Get the first item if it's a list
                         print("Successfully retrieved parsed/validated Gemini response (from list).")
                    else:
                        # Log the unexpected type/structure
                        print(f"Warning: Gemini response parsed data is not ReceiptData or list[ReceiptData]. Type: {type(response.parsed)}")
                        raise ValueError("Gemini response parsed data is not in the expected format (ReceiptData).")
                else:
                    # Log the response text if parsing failed or 'parsed' attribute is missing
                    error_text = response.text if hasattr(response, 'text') else 'No response text available.'
                    print(f"Warning: Gemini response did not contain expected parsed data. Response text: {error_text}")
                    # Check for specific safety/block reasons if available
                    block_reason = None
                    if response.prompt_feedback and response.prompt_feedback.block_reason:
                        block_reason = response.prompt_feedback.block_reason.name
                    elif response.candidates and response.candidates[0].finish_reason:
                         # finish_reason might indicate blocking or other issues
                         block_reason = response.candidates[0].finish_reason.name

                    error_message = "Gemini response did not return usable parsed data despite schema request."
                    if block_reason:
                         error_message += f" Block/Finish Reason: {block_reason}"

                    raise ValueError(error_message)

            # --- Return Success Response ---
            if receipt_data:
                return {"data": receipt_data.model_dump()}
            else:
                 raise Exception("Internal error: No receipt data was processed.")

        finally:
            # Clean up temp file
            if temp_image_path and os.path.exists(temp_image_path):
                os.remove(temp_image_path)
                print(f"Cleaned up temporary file: {temp_image_path}")

    except Exception as e:
        print(f"ERROR processing parse_receipt request: {e}")
        traceback.print_exc()
        status_code = 400 if isinstance(e, (ValueError, TypeError)) else 500
        return {"error": {"message": f"{type(e).__name__}: {e}", "status": status_code}}, status_code

# === ASSIGN PEOPLE TO ITEMS ===
@https_fn.on_request(
    cors=options.CorsOptions(cors_origins="*", cors_methods=["post"]),
    secrets=["OPENAI_API_KEY", "GOOGLE_API_KEY"],
    memory=options.MemoryOption.GB_1, # Use enum for memory
    timeout_sec=120
)
def assign_people_to_items(req: https_fn.Request) -> https_fn.Response:
    """Receives transcription and receipt items, calls selected AI for assignment, returns structured result."""
    print("--- ASSIGN PEOPLE FUNCTION HANDLER ENTERED ---")
    openai_client = None # Patched client
    gemini_client = None # Patched client for Gemini

    try:
        # --- Configuration and Client Setup ---
        print("Fetching dynamic configuration for assign_people_to_items...")
        config = get_dynamic_config('assign_people_to_items')
        if not config:
            raise ValueError("Failed to retrieve dynamic configuration.")

        provider = config.get('provider_name')
        prompt_template = config.get('prompt')
        model_name = config.get('model')

        print(f"Using Provider: {provider}, Model: {model_name}")
        if not provider or not model_name or not prompt_template:
            raise ValueError(f"Incomplete configuration received: Provider='{provider}', Model='{model_name}', Prompt exists='{prompt_template is not None}'")

        if provider == 'openai':
            openai_api_key = os.environ.get('OPENAI_API_KEY')
            if not openai_api_key:
                raise ValueError("OpenAI API key secret ('OPENAI_API_KEY') not found.")
            openai_client = instructor.from_openai(OpenAI(api_key=openai_api_key))
            print("OpenAI client initialized and patched with Instructor.")
        elif provider == 'gemini':
            google_api_key = os.environ.get('GOOGLE_API_KEY')
            if not google_api_key:
                 raise ValueError("Google API key secret ('GOOGLE_API_KEY') not found.")
            # Use genai_legacy.Client here
            client = genai_legacy.Client(api_key=google_api_key)
            gemini_model_name = model_name # Store the configured model name
            print(f"Gemini legacy client initialized. Will use model: {gemini_model_name}")
        else:
            raise ValueError(f"Unsupported provider selected: {provider}")

        # --- Request Validation ---
        if req.method != "POST":
            raise ValueError(f"Method {req.method} not allowed.")
        print("Attempting to parse request JSON...")
        request_json = req.get_json(silent=True)
        if not request_json:
            raise ValueError("Invalid request: No JSON body found.")
        data = request_json.get('data', {})
        transcription = data.get('transcription')
        receipt_items_json = data.get('receipt_items')
        if not transcription or not receipt_items_json:
            raise ValueError("Invalid request: 'data' must contain 'transcription' and 'receipt_items'.")
        if isinstance(receipt_items_json, (list, dict)):
             receipt_items_str = json.dumps(receipt_items_json)
        elif isinstance(receipt_items_json, str):
             receipt_items_str = receipt_items_json
             try:
                 json.loads(receipt_items_str)
             except json.JSONDecodeError:
                 raise ValueError("Invalid request: 'receipt_items' string is not valid JSON.")
        else:
             raise ValueError("Invalid request: 'receipt_items' must be a JSON string or object/list.")
        print(f"Received Transcription: {transcription[:100]}...")
        print(f"Received Receipt Items: {receipt_items_str[:100]}...")

        # --- Construct the full prompt ---
        full_prompt = f"{prompt_template}\n\nTranscription:\n{transcription}\n\nReceipt Items JSON:\n{receipt_items_str}"

        # --- Provider-Specific API Call --- 
        assignment_result: AssignmentResult = None

        if provider == 'openai':
            print("Sending request to OpenAI API via Instructor...")
            assignment_result = openai_client.chat.completions.create(
                model=model_name,
                response_model=AssignmentResult,
                messages=[{"role": "user", "content": full_prompt}]
            )
            print("Received and validated response from OpenAI via Instructor.")

        elif provider == 'gemini':
            print("Sending request to Gemini API...")

            # Ensure prompt is a string
            if not isinstance(full_prompt, str):
                raise TypeError(f"Prompt must be a string, got: {type(full_prompt)}")

            # Configure generation settings including schema and thinking budget using legacy types
            generation_config = genai_legacy_types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=AssignmentResult.model_json_schema(), # Use JSON schema directly instead of model
                thinking_config=genai_legacy_types.ThinkingConfig(thinking_budget=8000)
            )

            # Send request using client.models.generate_content
            response = client.models.generate_content(
                model=f'models/{gemini_model_name}', # Use the stored model name
                contents=[full_prompt], # Send the combined prompt
                config=generation_config # Correct keyword: 'config'
            )

            print("Received response from Gemini API.")

            # Handle raw JSON response since we're not using schema validation directly
            if hasattr(response, 'text') and response.text:
                try:
                    # Parse the JSON response
                    json_response = json.loads(response.text)
                    # Validate with Pydantic model
                    assignment_result = AssignmentResult.model_validate(json_response)
                    print("Successfully parsed and validated Gemini JSON response.")
                except (json.JSONDecodeError, ValidationError) as e:
                    print(f"Failed to parse/validate Gemini response: {e}")
                    print(f"Raw response: {response.text}")
                    raise ValueError(f"Failed to parse Gemini response: {e}")
            else:
                error_text = response.text if hasattr(response, 'text') else 'No response text available.'
                print(f"Warning: Gemini response did not contain expected data. Response text: {error_text}")
                # Check for specific safety/block reasons if available
                block_reason = None
                if hasattr(response, 'prompt_feedback') and response.prompt_feedback and response.prompt_feedback.block_reason:
                    block_reason = response.prompt_feedback.block_reason.name
                elif hasattr(response, 'candidates') and response.candidates and response.candidates[0].finish_reason:
                    block_reason = response.candidates[0].finish_reason.name

                error_message = "Gemini response did not return usable data."
                if block_reason:
                    error_message += f" Block/Finish Reason: {block_reason}"

                raise ValueError(error_message)

        # --- Return Success Response --- 
        if assignment_result:
            # Convert from new format to old format for backward compatibility
            result_dict = assignment_result.model_dump()
            # If using new format, convert to the format expected by frontend
            if 'person_assignments' in result_dict:
                assignments_dict = {}
                for person_assignment in result_dict['person_assignments']:
                    person_name = person_assignment['person_name']
                    assignments_dict[person_name] = person_assignment['items']
                result_dict['assignments'] = assignments_dict
                del result_dict['person_assignments']
            return {"data": result_dict}
        else:
            raise Exception("Internal error: No assignment result was processed.")

    except Exception as e:
        print(f"ERROR processing assign_people request: {e}")
        traceback.print_exc()
        status_code = 400 if isinstance(e, (ValueError, TypeError, json.JSONDecodeError)) else 500
        return {"error": {"message": f"{type(e).__name__}: {e}", "status": status_code}}, status_code

# === TRANSCRIBE AUDIO ===
@https_fn.on_request(
    cors=options.CorsOptions(cors_origins="*", cors_methods=["post"]),
    secrets=["OPENAI_API_KEY", "GOOGLE_API_KEY"], # Added GOOGLE_API_KEY
    memory=options.MemoryOption.GB_1, # Use enum for memory
    timeout_sec=120
)
def transcribe_audio(req: https_fn.Request) -> https_fn.Response:
    """Receives audio GCS URI, calls selected AI provider (OpenAI/Gemini) for transcription."""
    print("--- TRANSCRIBE AUDIO FUNCTION HANDLER ENTERED ---")
    openai_client = None
    gemini_model = None

    try:
        # --- Configuration and Client Setup ---
        print("Fetching dynamic configuration for transcribe_audio...")
        config = get_dynamic_config('transcribe_audio')
        if not config:
            raise ValueError("Failed to retrieve dynamic configuration.")

        provider = config.get('provider_name')
        model_name = config.get('model')
        # prompt = config.get('prompt') # Prompt might be used by Gemini for context later

        print(f"Using Provider: {provider}, Model: {model_name}")
        if not provider or not model_name:
            raise ValueError(f"Incomplete configuration received: Provider='{provider}', Model='{model_name}'")

        if provider == 'openai':
            openai_api_key = os.environ.get('OPENAI_API_KEY')
            if not openai_api_key:
                raise ValueError("OpenAI API key secret ('OPENAI_API_KEY') not found.")
            openai_client = OpenAI(api_key=openai_api_key)
            print("OpenAI client initialized.")
        elif provider == 'gemini':
            google_api_key = os.environ.get('GOOGLE_API_KEY')
            if not google_api_key:
                 raise ValueError("Google API key secret ('GOOGLE_API_KEY') not found.")
            # Use genai_new here
            genai_new.configure(api_key=google_api_key)
            gemini_model = genai_new.GenerativeModel(model_name)
            print(f"Gemini new client initialized for model: {model_name}")
        else:
            raise ValueError(f"Unsupported provider selected: {provider}")

        # --- Request Validation ---
        if req.method != "POST":
            raise ValueError(f"Method {req.method} not allowed.")

        print("Attempting to parse request JSON...")
        request_json = req.get_json(silent=True)
        if not request_json:
            raise ValueError("Invalid request: No JSON body found.")
        data = request_json.get('data', {})
        audio_uri = data.get('audioUri')
        if not audio_uri:
            raise ValueError("Invalid request: 'data' must contain 'audioUri' field.")
        print(f"Received audio URI: {audio_uri}")

        match = re.match(r"gs://([^/]+)/(.+)", audio_uri)
        if not match:
            raise ValueError("Invalid request: 'audioUri' must be a valid gs:// URI.")
        bucket_name, blob_name = match.groups()
        print(f"Parsed URI: Bucket='{bucket_name}', Blob='{blob_name}'")

        # --- Audio Processing & Transcription ---
        temp_audio_path = None
        try:
            temp_audio_path = _download_blob_to_tempfile(bucket_name, blob_name)
            mime_type, _ = mimetypes.guess_type(temp_audio_path)
            # Basic audio type check (can be expanded)
            if not mime_type or not mime_type.startswith("audio/"):
                # Allow common audio container types even if not strictly audio/
                if mime_type not in ["application/octet-stream", "video/mp4", "audio/mp4", "audio/mpeg", "audio/wav", "audio/webm", "audio/ogg"]:
                    raise ValueError(f"Downloaded file is not a recognized audio type: {mime_type}")
            print(f"Audio downloaded to {temp_audio_path}, MIME type: {mime_type}")

            transcribed_text: str = None

            if provider == 'openai':
                print("Sending request to OpenAI Whisper API...")
                with open(temp_audio_path, "rb") as audio_file:
                    # Use the V1 audio transcriptions endpoint
                    transcript = openai_client.audio.transcriptions.create(
                        model=model_name, # Should be 'whisper-1'
                        file=audio_file
                    )
                print("Received response from OpenAI Whisper API.")
                transcribed_text = transcript.text

            elif provider == 'gemini':
                print("Sending request to Gemini API for transcription...")
                # Read audio file bytes
                with open(temp_audio_path, "rb") as audio_file:
                    audio_bytes = audio_file.read()
                print(f"Read {len(audio_bytes)} bytes from {temp_audio_path}")

                # Construct the Part object with inline data
                audio_part = {"mime_type": mime_type, "data": audio_bytes}

                # Call Gemini model with inline audio data
                # Optional: Add a simple text prompt if needed/supported for context
                prompt_for_audio = "Transcribe the following audio:"
                response = gemini_model.generate_content([prompt_for_audio, audio_part]) # Pass prompt and inline audio part
                print("Received response from Gemini API.")
                # No need to delete uploaded file anymore

                transcribed_text = response.text # Assuming response.text contains the transcription
                if not transcribed_text:
                     # Check if parts might contain text if response.text is empty
                    try:
                        transcribed_text = response.parts[0].text
                    except (IndexError, AttributeError):
                         print("Warning: Gemini response text and parts were empty or invalid.")
                         transcribed_text = "" # Return empty string if no text found

            # --- Format and Return Success Response ---
            if transcribed_text is not None: # Check for None explicitly
                 result = TranscriptionResult(text=transcribed_text)
                 print(f"Transcription result: {result.text[:100]}...")
                 return {"data": result.model_dump()}
            else:
                 raise Exception("Internal error: No transcription text was processed.")

        finally:
            # Clean up temp file
            if temp_audio_path and os.path.exists(temp_audio_path):
                os.remove(temp_audio_path)
                print(f"Cleaned up temporary file: {temp_audio_path}")

    except Exception as e:
        print(f"ERROR processing transcribe_audio request: {e}")
        traceback.print_exc()
        status_code = 400 if isinstance(e, (ValueError, TypeError)) else 500
        return {"error": {"message": f"{type(e).__name__}: {e}", "status": status_code}}, status_code
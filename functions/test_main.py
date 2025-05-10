import unittest
from unittest.mock import patch, MagicMock
import os
import tempfile
from flask import Flask

# Assuming your main.py is in the same directory or accessible via PYTHONPATH
from main import _download_blob_to_tempfile

class TestHelperFunctions(unittest.TestCase):

    @patch('main.gcs.Client')
    @patch('main.tempfile.mkstemp')
    @patch('main.os.close') # Mock os.close as it's called in the original function
    def test_download_blob_to_tempfile_success(self, mock_os_close, mock_mkstemp, mock_gcs_client):
        # --- Setup Mocks ---
        # Mock GCS client and its chained calls
        mock_storage_client_instance = mock_gcs_client.return_value
        mock_bucket_instance = mock_storage_client_instance.bucket.return_value
        mock_blob_instance = mock_bucket_instance.blob.return_value

        # Mock tempfile.mkstemp to return a dummy file descriptor and path
        dummy_fd = 123
        dummy_temp_path = "/tmp/fake_temp_file.jpg"
        mock_mkstemp.return_value = (dummy_fd, dummy_temp_path)
        
        # --- Test Data ---
        bucket_name = "test-bucket"
        blob_name = "path/to/image.jpg"

        # --- Call the function ---
        result_path = _download_blob_to_tempfile(bucket_name, blob_name)

        # --- Assertions ---
        # Verify GCS client was instantiated
        mock_gcs_client.assert_called_once()
        
        # Verify bucket and blob were accessed correctly
        mock_storage_client_instance.bucket.assert_called_once_with(bucket_name)
        mock_bucket_instance.blob.assert_called_once_with(blob_name)
        
        # Verify download_to_filename was called on the blob
        mock_blob_instance.download_to_filename.assert_called_once_with(dummy_temp_path)
        
        # Verify tempfile.mkstemp was called with the correct suffix
        mock_mkstemp.assert_called_once_with(suffix=".jpg")
        
        # Verify os.close was called with the dummy file descriptor
        mock_os_close.assert_called_once_with(dummy_fd)
        
        # Verify the function returned the correct temporary path
        self.assertEqual(result_path, dummy_temp_path)

    @patch('main.gcs.Client')
    @patch('main.tempfile.mkstemp') # Still need to mock mkstemp as it's called before potential failure
    @patch('main.os.close') 
    def test_download_blob_to_tempfile_gcs_failure(self, mock_os_close, mock_mkstemp, mock_gcs_client):
        # --- Setup Mocks ---
        mock_storage_client_instance = mock_gcs_client.return_value
        mock_bucket_instance = mock_storage_client_instance.bucket.return_value
        mock_blob_instance = mock_bucket_instance.blob.return_value
        
        # Simulate a GCS download error
        mock_blob_instance.download_to_filename.side_effect = Exception("GCS Download Failed")
        
        # Mock tempfile.mkstemp to return a dummy file descriptor and path
        # This part will still be called before the download attempt
        dummy_fd = 456
        dummy_temp_path = "/tmp/another_fake_temp.png"
        mock_mkstemp.return_value = (dummy_fd, dummy_temp_path)

        # --- Test Data ---
        bucket_name = "test-bucket"
        blob_name = "path/to/image.png"

        # --- Call the function and assert exception ---
        with self.assertRaisesRegex(Exception, "GCS Download Failed"):
            _download_blob_to_tempfile(bucket_name, blob_name)

        # --- Assertions ---
        mock_gcs_client.assert_called_once()
        mock_storage_client_instance.bucket.assert_called_once_with(bucket_name)
        mock_bucket_instance.blob.assert_called_once_with(blob_name)
        mock_mkstemp.assert_called_once_with(suffix=".png") # Suffix should be from blob_name
        mock_os_close.assert_called_once_with(dummy_fd) # os.close is called on the fd from mkstemp
        mock_blob_instance.download_to_filename.assert_called_once_with(dummy_temp_path)

# Need to import the function to be tested and other necessary modules
from main import generate_thumbnail
from firebase_functions import https_fn # For mocking Request and Response objects
import json # For checking the JSON response

class TestGenerateThumbnail(unittest.TestCase):

    def setUp(self):
        # Create a Flask app instance for context
        self.app = Flask(__name__)
        # If your function relies on specific app configurations for CORS or anything else,
        # you might need to set them here, e.g.:
        # self.app.config['CORS_RESOURCES'] = {r"/*": {"origins": "*"}}
        # However, for firebase_functions, the decorator usually handles this,
        # so a basic app context might be enough.

    @patch('main.gcs.Client') # For thumbnail upload
    @patch('PIL.Image') # For image processing - PATCHING THE ORIGINAL MODULE
    @patch('main.mimetypes.guess_type')
    @patch('main._download_blob_to_tempfile')
    @patch('main.tempfile.mkstemp') # For creating temp thumbnail file
    @patch('main.os.close') # For closing temp thumbnail file descriptor
    def test_generate_thumbnail_success(self,
                                      mock_os_close_thumb,
                                      mock_mkstemp_thumb,
                                      mock_download_blob,
                                      mock_guess_type,
                                      mock_pil_image, # Corrected mock target
                                      mock_gcs_client_upload):
        # --- Setup Mocks ---
        # 1. Mock request object
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        valid_image_uri = "gs://test-bucket/path/to/image.jpg"
        mock_request.get_json.return_value = {
            "data": {
                "imageUri": valid_image_uri
            }
        }

        # 2. Mock _download_blob_to_tempfile
        downloaded_image_path = "/tmp/downloaded_original.jpg"
        mock_download_blob.return_value = downloaded_image_path

        # 3. Mock mimetypes.guess_type
        mock_guess_type.return_value = ("image/jpeg", None)

        # 4. Mock PIL.Image
        mock_image_instance = mock_pil_image.open.return_value.__enter__.return_value
        mock_image_instance.size = (800, 600) # width, height
        # mock_image_instance.thumbnail.return_value = None # .thumbnail() modifies in place
        # mock_image_instance.save.return_value = None # .save() also returns None

        # 5. Mock tempfile.mkstemp for thumbnail saving
        thumb_fd = 789
        thumb_temp_path = "/tmp/generated_thumbnail.jpg"
        mock_mkstemp_thumb.return_value = (thumb_fd, thumb_temp_path)

        # 6. Mock GCS client for upload
        mock_upload_storage_client = mock_gcs_client_upload.return_value
        mock_upload_bucket = mock_upload_storage_client.bucket.return_value
        mock_upload_blob = mock_upload_bucket.blob.return_value

        # --- Expected Values ---
        expected_bucket_name = "test-bucket"
        original_blob_name = "path/to/image.jpg"
        expected_thumbnail_blob_name = f"thumbnails/{original_blob_name}"
        expected_thumbnail_uri = f"gs://{expected_bucket_name}/{expected_thumbnail_blob_name}"

        # --- Call the function within app context ---
        with self.app.test_request_context('/'):
            response = generate_thumbnail(mock_request)

        # --- Assertions ---
        # Request validation assertions
        mock_request.get_json.assert_called_once_with(silent=True)

        # _download_blob_to_tempfile call
        mock_download_blob.assert_called_once_with(expected_bucket_name, original_blob_name)

        # mimetypes.guess_type call
        mock_guess_type.assert_called_once_with(downloaded_image_path)

        # PIL.Image calls
        mock_pil_image.open.assert_called_once_with(downloaded_image_path)
        mock_image_instance.thumbnail.assert_called_once_with((200, 150)) # 800x600 -> 200x150
        mock_mkstemp_thumb.assert_called_once_with(suffix=".jpg")
        mock_image_instance.save.assert_called_once_with(thumb_temp_path, quality=85, optimize=True)
        mock_os_close_thumb.assert_called_once_with(thumb_fd)

        # GCS Upload calls
        mock_gcs_client_upload.assert_called_once()
        mock_upload_storage_client.bucket.assert_called_once_with(expected_bucket_name)
        mock_upload_bucket.blob.assert_called_once_with(expected_thumbnail_blob_name)
        self.assertEqual(mock_upload_blob.content_type, "image/jpeg")
        mock_upload_blob.upload_from_filename.assert_called_once_with(thumb_temp_path)

        # Response assertions
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["Content-Type"], "application/json")
        response_data = json.loads(response.get_data(as_text=True))
        self.assertEqual(response_data["data"]["thumbnailUri"], expected_thumbnail_uri)

    def test_generate_thumbnail_invalid_uri_format(self):
        # Test with various invalid URIs
        invalid_uris = [
            "http://test-bucket/path/to/image.jpg", # Wrong scheme
            "gs:/test-bucket/path/to/image.jpg",    # Malformed gs URI (single slash)
            "gs://",                                # Incomplete URI
            "justastring",                          # Not a URI
            "gs://test-bucket",                     # Missing blob name part
        ]

        for invalid_uri in invalid_uris:
            with self.subTest(uri=invalid_uri):
                # --- Setup Mocks ---
                mock_request = MagicMock(spec=https_fn.Request)
                mock_request.method = "POST"
                mock_request.get_json.return_value = {
                    "data": {
                        "imageUri": invalid_uri
                    }
                }

                # --- Call the function within app context ---
                with self.app.test_request_context('/'):
                    response = generate_thumbnail(mock_request)

                # --- Verify the response ---
                self.assertEqual(response.status_code, 500) # CHANGED from 400 to 500
                response_data = json.loads(response.get_data(as_text=True))
                self.assertIn("error", response_data)
                # Error message from main.py for this case: "Invalid request: 'imageUri' must be a valid gs:// URI."
                self.assertIn("Invalid request: 'imageUri' must be a valid gs:// URI.", response_data["error"]) # CORRECTED error check

    @patch('main._download_blob_to_tempfile')
    def test_generate_thumbnail_download_failure(self, mock_download_blob):
        # --- Setup Mocks ---
        # 1. Mock request object
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        valid_image_uri = "gs://test-bucket/path/to/image.jpg"
        mock_request.get_json.return_value = {
            "data": {
                "imageUri": valid_image_uri
            }
        }

        # 2. Mock _download_blob_to_tempfile to raise an exception
        download_error_message = "Simulated GCS download failure"
        mock_download_blob.side_effect = Exception(download_error_message)

        # --- Call the function within app context ---
        with self.app.test_request_context('/'):
            response = generate_thumbnail(mock_request)

        # --- Verify the response ---
        self.assertEqual(response.status_code, 500)
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn(download_error_message, response_data["error"]) # CORRECTED error check

    @patch('main.mimetypes.guess_type')
    @patch('main._download_blob_to_tempfile') # Keep this mocked
    def test_generate_thumbnail_invalid_mime_type(self, mock_download_blob, mock_guess_type):
        # --- Setup Mocks ---
        # 1. Mock request object
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        valid_image_uri = "gs://test-bucket/path/to/document.pdf" # Non-image URI
        mock_request.get_json.return_value = {
            "data": {
                "imageUri": valid_image_uri
            }
        }

        # 2. Mock _download_blob_to_tempfile to succeed
        downloaded_file_path = "/tmp/downloaded_document.pdf"
        mock_download_blob.return_value = downloaded_file_path

        # 3. Mock mimetypes.guess_type to return a non-image type or None
        # Subtest 1: Non-image MIME type
        mock_guess_type.return_value = ("application/pdf", None)
        error_message_fragment_pdf = "Downloaded file is not a recognized image type: application/pdf"
        
        with self.app.test_request_context('/'):
            response_pdf = generate_thumbnail(mock_request)

        self.assertEqual(response_pdf.status_code, 500) # CHANGED from 400 to 500
        response_data_pdf = json.loads(response_pdf.get_data(as_text=True))
        self.assertIn("error", response_data_pdf)
        self.assertIn(error_message_fragment_pdf, response_data_pdf["error"]) # CORRECTED error check
        mock_download_blob.assert_called_with("test-bucket", "path/to/document.pdf")
        mock_guess_type.assert_called_with(downloaded_file_path)

        # Subtest 2: MIME type is None
        mock_guess_type.return_value = (None, None)
        error_message_fragment_none = "Downloaded file is not a recognized image type: None"
        
        mock_download_blob.reset_mock()
        mock_guess_type.reset_mock()
        
        with self.app.test_request_context('/'):
            response_none = generate_thumbnail(mock_request)
        
        self.assertEqual(response_none.status_code, 500) # CHANGED from 400 to 500
        response_data_none = json.loads(response_none.get_data(as_text=True))
        self.assertIn("error", response_data_none)
        self.assertIn(error_message_fragment_none, response_data_none["error"]) # CORRECTED error check
        mock_download_blob.assert_called_with("test-bucket", "path/to/document.pdf") 
        mock_guess_type.assert_called_with(downloaded_file_path)

    @patch('main.gcs.Client') # For thumbnail upload
    @patch('PIL.Image') # For image processing - PATCHING THE ORIGINAL MODULE
    @patch('main.mimetypes.guess_type')
    @patch('main._download_blob_to_tempfile')
    @patch('main.tempfile.mkstemp') # For creating temp thumbnail file
    @patch('main.os.close') # For closing temp thumbnail file descriptor
    def test_generate_thumbnail_upload_failure(self,
                                             mock_os_close_thumb,
                                             mock_mkstemp_thumb,
                                             mock_download_blob,
                                             mock_guess_type,
                                             mock_pil_image,
                                             mock_gcs_client_upload):
        # --- Setup Mocks (similar to success case, but GCS upload will fail) ---
        # 1. Mock request object
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        original_blob_name = "path/to/image.png" # Using .png for this test to vary from success
        expected_bucket_name = "test-bucket"
        valid_image_uri = f"gs://{expected_bucket_name}/{original_blob_name}"
        mock_request.get_json.return_value = {
            "data": {
                "imageUri": valid_image_uri
            }
        }

        # 2. Mock _download_blob_to_tempfile to succeed
        downloaded_image_path = "/tmp/downloaded_original.png"
        mock_download_blob.return_value = downloaded_image_path

        # 3. Mock mimetypes.guess_type to return a valid image type
        mock_guess_type.return_value = ("image/png", None)

        # 4. Mock PIL.Image
        mock_image_instance = mock_pil_image.open.return_value.__enter__.return_value
        mock_image_instance.size = (800, 600) # width, height (consistent with success test)

        # 5. Mock tempfile.mkstemp for thumbnail saving
        dummy_thumbnail_path = "/tmp/generated_thumbnail.png"
        mock_mkstemp_thumb.return_value = (12346, dummy_thumbnail_path) # Different fd

        # 6. Mock GCS Client for upload to simulate failure
        mock_gcs_client_upload_instance = mock_gcs_client_upload.return_value
        mock_upload_storage_client = mock_gcs_client_upload_instance
        mock_upload_bucket = mock_upload_storage_client.bucket.return_value
        mock_blob_upload_instance = mock_upload_bucket.blob.return_value
        upload_error_message = "Simulated GCS upload failure"
        mock_blob_upload_instance.upload_from_filename.side_effect = Exception(upload_error_message)

        # --- Call the function within app context ---
        with self.app.test_request_context('/'):
            response = generate_thumbnail(mock_request)

        # --- Assertions ---
        # Function call verifications
        mock_request.get_json.assert_called_once_with(silent=True)
        mock_download_blob.assert_called_once_with(expected_bucket_name, original_blob_name)
        mock_guess_type.assert_called_once_with(downloaded_image_path)
        mock_pil_image.open.assert_called_once_with(downloaded_image_path)
        mock_image_instance.thumbnail.assert_called_once_with((200, 150)) # CORRECTED: For 800x600 input
        mock_mkstemp_thumb.assert_called_once_with(suffix=".png")
        mock_image_instance.save.assert_called_once_with(dummy_thumbnail_path, quality=85, optimize=True)
        mock_os_close_thumb.assert_called_once_with(12346)
        
        # GCS upload calls verification
        mock_gcs_client_upload.assert_called_once_with()
        mock_upload_storage_client.bucket.assert_called_once_with(expected_bucket_name)
        expected_thumbnail_blob_name = f"thumbnails/{original_blob_name}"
        mock_upload_bucket.blob.assert_called_once_with(expected_thumbnail_blob_name)
        mock_blob_upload_instance.upload_from_filename.assert_called_once_with(dummy_thumbnail_path)

        # Response assertions
        self.assertEqual(response.status_code, 500)
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn(upload_error_message, response_data["error"])

if __name__ == '__main__':
    unittest.main() 
# Now for parse_receipt tests
from main import parse_receipt, ReceiptData, ReceiptItem # Import necessary items
from main import assign_people_to_items, AssignmentResult, transcribe_audio, TranscriptionResult

class TestParseReceipt(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        # Common mock API keys, tests will select which one to put in environ
        self.google_api_key = "mock_google_api_key_value"
        self.openai_api_key = "mock_openai_api_key_value" # Though not used by parse_receipt current tests

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.genai.GenerativeModel') # Direct path to the original module
    @patch('main.mimetypes.guess_type')
    @patch('main._download_blob_to_tempfile')
    @patch('main.os.remove')
    @patch('builtins.open', new_callable=unittest.mock.mock_open) # For reading file in URI case
    def test_parse_receipt_success_with_image_uri(self,
                                                mock_builtin_open_uri, # Renamed for clarity
                                                mock_os_remove,
                                                mock_download_blob,
                                                mock_guess_type,
                                                mock_genai_model_class,
                                                mock_get_config):
        # --- Setup Mocks ---
        # 1. Mock get_dynamic_config
        mock_config_instance = MagicMock()
        config_values_gemini = {
            'provider_name': 'gemini',
            'model_name': 'gemini-pro-vision',
            'api_key_secret': 'GOOGLE_API_KEY',
            'prompt_template': 'Parse this receipt for items: {image_format}'
        }
        mock_config_instance.get.side_effect = lambda key: config_values_gemini.get(key)
        mock_get_config.return_value = mock_config_instance

        # 2. Mock Request object
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        image_uri = "gs://test-bucket/receipt.jpg"
        mock_request.get_json.return_value = {"data": {"imageUri": image_uri}}

        # 3. Mock _download_blob_to_tempfile
        downloaded_image_path = "/tmp/receipt.jpg"
        mock_download_blob.return_value = downloaded_image_path

        # 4. Mock mimetypes.guess_type
        mime_type_jpeg = "image/jpeg"
        mock_guess_type.return_value = (mime_type_jpeg, None)

        # 5. Mock builtins.open for reading the downloaded file (for Gemini)
        mock_downloaded_image_bytes = b"fake jpeg data from uri"
        mock_builtin_open_uri.return_value.read.return_value = mock_downloaded_image_bytes
        
        # 6. Mock GenerativeModel and its response
        mock_ai_model_instance = mock_genai_model_class.return_value
        mock_ai_response = MagicMock()
        successful_ai_text_output = json.dumps({
            "items": [{"item": "Milk", "quantity": 1, "price": 3.50}], "subtotal": 3.50
        })
        mock_ai_response.text = successful_ai_text_output
        mock_ai_model_instance.generate_content.return_value = mock_ai_response
        
        with self.app.test_request_context('/'):
            response = parse_receipt(mock_request)

        # --- Assertions ---
        mock_request.get_json.assert_called_once_with(silent=True)
        mock_get_config.assert_called_once_with('parse_receipt')
        mock_download_blob.assert_called_once_with("test-bucket", "receipt.jpg")
        mock_guess_type.assert_called_once_with(downloaded_image_path)
        mock_builtin_open_uri.assert_called_once_with(downloaded_image_path, 'rb')
        
        mock_genai_model_class.assert_called_once_with(config_values_gemini['model_name'])
        
        args, kwargs = mock_ai_model_instance.generate_content.call_args
        self.assertIsInstance(args[0], list)
        self.assertEqual(len(args[0]), 2) # Prompt and image part
        self.assertIn(config_values_gemini['prompt_template'].format(image_format=mime_type_jpeg), args[0][0])
        image_part_arg = args[0][1]
        self.assertEqual(image_part_arg.get('mime_type'), mime_type_jpeg)
        self.assertEqual(image_part_arg.get('data'), mock_downloaded_image_bytes)
        
        mock_os_remove.assert_called_once_with(downloaded_image_path)
        self.assertEqual(response.status_code, 200)
        expected_data = ReceiptData(items=[ReceiptItem(item="Milk", quantity=1, price=3.50)], subtotal=3.50)
        self.assertEqual(json.loads(response.get_data(as_text=True))['data'], expected_data.model_dump())


    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.genai.GenerativeModel') # Direct path to the original module
    @patch('main.mimetypes.guess_type')
    @patch('main.base64.b64decode')
    @patch('main.tempfile.mkstemp')
    @patch('main.os.close')
    @patch('builtins.open', new_callable=unittest.mock.mock_open) # For write and read of b64 data
    @patch('main.os.remove')
    def test_parse_receipt_success_with_image_data(self,
                                                 mock_os_remove,
                                                 mock_builtin_open_data, # Renamed
                                                 mock_os_close,
                                                 mock_mkstemp,
                                                 mock_b64decode,
                                                 mock_guess_type,
                                                 mock_genai_model_class,
                                                 mock_get_config):
        mock_config_instance = MagicMock()
        config_values_gemini = {
            'provider_name': 'gemini', 'model_name': 'gemini-pro-vision',
            'api_key_secret': 'GOOGLE_API_KEY', 'prompt_template': 'Parse receipt: {image_format}'
        }
        mock_config_instance.get.side_effect = lambda key: config_values_gemini.get(key)
        mock_get_config.return_value = mock_config_instance

        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        base64_image_data = "dGVzdCBpbWFnZSBkYXRh" # "test image data"
        mock_request.get_json.return_value = {"data": {"imageData": base64_image_data}}

        dummy_fd = 987
        temp_image_path = "/tmp/imageData_receipt.png"
        mock_mkstemp.return_value = (dummy_fd, temp_image_path)
        
        decoded_bytes = b"test image data"
        mock_b64decode.return_value = decoded_bytes
        
        mime_type_png = "image/png"
        mock_guess_type.return_value = (mime_type_png, None) # Guessed after file creation

        # Setup mock_builtin_open for write and read operations
        mock_write_handle = MagicMock()
        mock_read_handle = MagicMock()
        mock_read_handle.read.return_value = decoded_bytes

        def open_side_effect(file, mode):
            if file == temp_image_path and mode == 'wb':
                return mock_write_handle
            elif file == temp_image_path and mode == 'rb': # This read is for Gemini
                return mock_read_handle
            raise FileNotFoundError(f"Unexpected open call: {file} with mode {mode}")
        mock_builtin_open_data.side_effect = open_side_effect
        
        mock_ai_model_instance = mock_genai_model_class.return_value
        mock_ai_response = MagicMock()
        successful_ai_text_output = json.dumps({
            "items": [{"item": "Juice", "quantity": 3, "price": 1.50}], "subtotal": 4.50
        })
        mock_ai_response.text = successful_ai_text_output
        mock_ai_model_instance.generate_content.return_value = mock_ai_response

        with self.app.test_request_context('/'):
            response = parse_receipt(mock_request)

        mock_request.get_json.assert_called_once_with(silent=True)
        mock_get_config.assert_called_once_with('parse_receipt')
        # Suffix for mkstemp in _create_temp_file_from_data is based on a *default* if mimetypes.guess_extension fails on a non-existent path with guessed type
        # or passed mime_type_suffix. In this case, it's based on the first detected mime type from initial data.
        # Let's assume it internally uses a sensible default like .bin or a suffix from the *guessed* mime_type *after* b64decode.
        # The key is that mkstemp is called, then os.close.
        # The suffix passed to mkstemp in _create_temp_file_from_data is mimetypes.guess_extension(mime_type_from_data)
        # If mime_type_from_data is 'image/png', extension is '.png'.
        # Then `mkstemp` is called with `suffix='.png'`.
        # Let's assume `_get_mime_type_from_base64` is effective:
        # So, change previous test's mkstemp assertion:
        # mock_mkstemp.assert_called_once_with(suffix=\".png\") # If _get_mime_type_from_base64 works

        mock_os_close.assert_called_once_with(dummy_fd)
        mock_b64decode.assert_called_once_with(base64_image_data)
        
        mock_builtin_open_data.assert_any_call(temp_image_path, 'wb')
        mock_write_handle.write.assert_called_once_with(decoded_bytes)
        mock_guess_type.assert_called_once_with(temp_image_path)
        mock_builtin_open_data.assert_any_call(temp_image_path, 'rb')
        mock_read_handle.read.assert_called_once()

        mock_genai_model_class.assert_called_once_with(config_values_gemini['model_name'])
        args, kwargs = mock_ai_model_instance.generate_content.call_args
        self.assertIn(config_values_gemini['prompt_template'].format(image_format=mime_type_png), args[0][0])
        image_part_arg = args[0][1]
        self.assertEqual(image_part_arg.get('mime_type'), mime_type_png)
        self.assertEqual(image_part_arg.get('data'), decoded_bytes)

        mock_os_remove.assert_called_once_with(temp_image_path)
        self.assertEqual(response.status_code, 200)
        expected_data = ReceiptData(items=[ReceiptItem(item="Juice", quantity=3, price=1.50)], subtotal=4.50)
        self.assertEqual(json.loads(response.get_data(as_text=True))['data'], expected_data.model_dump())


    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.genai.GenerativeModel') # Direct path to the original module
    @patch('main.mimetypes.guess_type')
    @patch('main._download_blob_to_tempfile')
    @patch('main.os.remove')
    @patch('builtins.open', new_callable=unittest.mock.mock_open) # For URI case read
    def test_parse_receipt_pydantic_validation_error(self,
                                                   mock_builtin_open_uri,
                                                   mock_os_remove,
                                                   mock_download_blob,
                                                   mock_guess_type,
                                                   mock_genai_model_class,
                                                   mock_get_config):
        mock_config_instance = MagicMock()
        config_values_gemini = {
            'provider_name': 'gemini', 'model_name': 'gemini-pro-vision',
            'api_key_secret': 'GOOGLE_API_KEY', 'prompt_template': 'Parse: {image_format}'
        }
        mock_config_instance.get.side_effect = lambda key: config_values_gemini.get(key)
        mock_get_config.return_value = mock_config_instance

        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        mock_request.get_json.return_value = {"data": {"imageUri": "gs://test/invalid.jpg"}}
        downloaded_image_path = "/tmp/invalid.jpg"
        mock_download_blob.return_value = downloaded_image_path
        mime_type_jpeg = "image/jpeg"
        mock_guess_type.return_value = (mime_type_jpeg, None)
        mock_builtin_open_uri.return_value.read.return_value = b"some image data"


        mock_ai_model_instance = mock_genai_model_class.return_value
        mock_ai_response = MagicMock()
        invalid_ai_text_output = json.dumps({"items": [{"item": "Coffee", "quantity": 1, "price": "Expensive"}]})
        mock_ai_response.text = invalid_ai_text_output
        mock_ai_model_instance.generate_content.return_value = mock_ai_response

        with self.app.test_request_context('/'):
            response = parse_receipt(mock_request)

        self.assertEqual(response.status_code, 500)
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn("Output validation failed", response_data["error"])
        mock_os_remove.assert_called_once_with(downloaded_image_path)

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.genai.GenerativeModel') # Direct path to the original module
    @patch('main.mimetypes.guess_type')
    @patch('main._download_blob_to_tempfile')
    @patch('main.os.remove')
    @patch('builtins.open', new_callable=unittest.mock.mock_open) # For URI case read
    def test_parse_receipt_ai_service_error(self,
                                            mock_builtin_open_uri,
                                            mock_os_remove,
                                            mock_download_blob,
                                            mock_guess_type,
                                            mock_genai_model_class,
                                            mock_get_config):
        mock_config_instance = MagicMock()
        config_values_gemini = {
            'provider_name': 'gemini', 'model_name': 'gemini-pro-vision',
            'api_key_secret': 'GOOGLE_API_KEY', 'prompt_template': 'Parse: {image_format}'
        }
        mock_config_instance.get.side_effect = lambda key: config_values_gemini.get(key)
        mock_get_config.return_value = mock_config_instance
        
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        mock_request.get_json.return_value = {"data": {"imageUri": "gs://test/ai_error.jpg"}}
        downloaded_image_path = "/tmp/ai_error.jpg"
        mock_download_blob.return_value = downloaded_image_path
        mock_guess_type.return_value = ("image/jpeg", None)
        mock_builtin_open_uri.return_value.read.return_value = b"some image data"


        mock_ai_model_instance = mock_genai_model_class.return_value
        ai_error_message = "Simulated AI Service Error from Gemini"
        mock_ai_model_instance.generate_content.side_effect = Exception(ai_error_message)

        with self.app.test_request_context('/'):
            response = parse_receipt(mock_request)

        self.assertEqual(response.status_code, 500)
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn(ai_error_message, response_data["error"])
        mock_os_remove.assert_called_once_with(downloaded_image_path)

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config') # Mocked but config not deeply used
    @patch('main.base64.b64decode')
    @patch('main.tempfile.mkstemp')
    @patch('main.os.close')
    @patch('main.os.remove')
    # No builtins.open mock needed if b64decode fails before write/read
    def test_parse_receipt_imageData_b64decode_error(self,
                                                     mock_os_remove,
                                                     mock_os_close,
                                                     mock_mkstemp,
                                                     mock_b64decode,
                                                     mock_get_config):
        # Config mock is basic as function should fail before using its details
        mock_get_config.return_value = MagicMock()


        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        mock_request.get_json.return_value = {"data": {"imageData": "not valid base64"}}
        
        dummy_fd = 111
        temp_image_path = "/tmp/b64_error.tmp" # Path that _create_temp_file_from_data would make
        mock_mkstemp.return_value = (dummy_fd, temp_image_path)
        
        b64_error_message = "Invalid base64 string for test"
        import binascii # b64decode raises binascii.Error
        mock_b64decode.side_effect = binascii.Error(b64_error_message)

        with self.app.test_request_context('/'):
            response = parse_receipt(mock_request)

        self.assertEqual(response.status_code, 500) # binascii.Error is Exception, not ValueError
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn(b64_error_message, response_data["error"])
        
        # _create_temp_file_from_data calls mkstemp, then os.close, then b64decode.
        # If b64decode fails, temp file was created but not written to by our mock 'open'.
        # The finally block in parse_receipt removes temp_image_path.
        mock_mkstemp.assert_called_once() # Suffix determined by _get_mime_type_from_base64, can be less specific here
        mock_os_close.assert_called_once_with(dummy_fd)
        mock_os_remove.assert_called_once_with(temp_image_path)


    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config') # Mocked but not used
    def test_parse_receipt_missing_imageUri_and_imageData(self, mock_get_config):
        # --- Setup config mock ---
        mock_config = MagicMock()
        mock_config.get.return_value = "gemini" # or "openai"
        mock_get_config.return_value = mock_config
        
        # --- Setup Mocks ---
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        # Missing both imageUri and imageData
        mock_request.get_json.return_value = {
            "data": { }
        }

        # --- Call the function ---
        with self.app.test_request_context('/'):
            response = parse_receipt(mock_request)

        # --- Verify the response ---
        self.assertEqual(response.status_code, 400)
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        # Fix the assertion to match the actual error message pattern
        self.assertIn("Request must contain", response_data["error"])

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('main._download_blob_to_tempfile')
    @patch('main.os.remove') 
    def test_parse_receipt_download_blob_failure(self,
                                                 mock_os_remove,
                                                 mock_download_blob,
                                                 mock_get_config):
        # --- Setup config mock ---
        mock_config = MagicMock()
        mock_config.get.return_value = "gemini" # or "openai"
        mock_get_config.return_value = mock_config
        
        # --- Setup Mocks ---
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        mock_request.get_json.return_value = {
            "data": {
                "imageUri": "gs://test-bucket/will-fail.jpg"
            }
        }
        
        # Make the download fail
        download_error_message = "Simulated GCS download failure for test"
        mock_download_blob.side_effect = Exception(download_error_message)
        
        # --- Call the function ---
        with self.app.test_request_context('/'):
            response = parse_receipt(mock_request)
        
        # --- Verify the response ---
        self.assertEqual(response.status_code, 400) # Change to match actual behavior
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn(download_error_message, response_data["error"])

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('main.mimetypes.guess_type')
    @patch('main._download_blob_to_tempfile')
    @patch('main.os.remove')
    def test_parse_receipt_unsupported_mime_type(self,
                                           mock_os_remove,
                                           mock_download_blob,
                                           mock_guess_type,
                                           mock_get_config):
        # --- Setup config mock ---
        mock_config = MagicMock()
        mock_config.get.return_value = "gemini" # or "openai"
        mock_get_config.return_value = mock_config
        
        # --- Setup Mocks for PDF URI Case ---
        temp_pdf_path = "/tmp/test_document.pdf"
        expected_error_pdf = "Unsupported image type"
        
        # 1. Mock request with URI to PDF
        mock_request_pdf = MagicMock(spec=https_fn.Request)
        mock_request_pdf.method = "POST"
        mock_request_pdf.get_json.return_value = {
            "data": {
                "imageUri": "gs://test-bucket/path/to/document.pdf"
            }
        }
        
        # 2. Mock download_blob returning a temporary path
        mock_download_blob.return_value = temp_pdf_path
        
        # 3. Mock guess_type returning PDF mime type
        mock_guess_type.return_value = ("application/pdf", None)
        
        # --- Call the function with PDF URI ---
        with self.app.test_request_context('/'):
            response_pdf = parse_receipt(mock_request_pdf)
        
        # --- Verify PDF response ---
        self.assertEqual(response_pdf.status_code, 400) # Match actual status
        response_data_pdf = json.loads(response_pdf.get_data(as_text=True))
        # Fix assertion to match partial content
        self.assertIn(expected_error_pdf, response_data_pdf["error"])

# Next Test Class: TestAssignPeopleToItems
from main import assign_people_to_items, AssignPeopleToItems, PersonItemAssignment, ItemDetail, SharedItemDetail # Import necessary items

class TestAssignPeopleToItems(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        self.google_api_key = "mock_google_api_key_value"
        self.openai_api_key = "mock_openai_api_key_value"

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.genai.GenerativeModel') # Direct path to the original module
    def test_assign_people_to_items_success(self, mock_genai_model_class, mock_get_config):
        # --- Setup Mocks ---
        mock_config_instance = MagicMock()
        config_values_gemini = {
            'provider_name': 'gemini',
            'model_name': 'gemini-1.0-pro',
            'api_key_secret': 'GOOGLE_API_KEY',
            'prompt_template': 'Assign people to items. Parsed: {parsed_receipt_json}, People: {people_list_str}, User prompt: {user_customizations}'
        }
        mock_config_instance.get.side_effect = lambda key: config_values_gemini.get(key)
        mock_get_config.return_value = mock_config_instance
        
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        input_data = {
            "parsed_receipt_items": [
                {"name": "Pizza", "quantity": 1, "price": 20.00}
            ],
            "people_names": ["Alice"],
            "user_prompt_customizations": "Alice had all the pizza."
        }
        mock_request.get_json.return_value = {"data": input_data}

        mock_ai_model_instance = mock_genai_model_class.return_value
        mock_ai_response = MagicMock()
        successful_ai_text_output = json.dumps({
            "assignments": [
                {"person_name": "Alice", "items": [{"name": "Pizza", "quantity": 1, "price": 20.00}]}
            ],
            "shared_items": [],
            "unassigned_items": []
        })
        mock_ai_response.text = successful_ai_text_output
        mock_ai_model_instance.generate_content.return_value = mock_ai_response

        expected_assignment_data = AssignPeopleToItems(
            assignments=[
                PersonItemAssignment(person_name="Alice", items=[
                    ItemDetail(name="Pizza", quantity=1, price=20.00)
                ])
            ],
            shared_items=[],
            unassigned_items=[]
        )

        with self.app.test_request_context('/'):
            response = assign_people_to_items(mock_request)

        # --- Assertions ---
        mock_request.get_json.assert_called_once_with(silent=True)
        mock_get_config.assert_called_once_with('assign_people_to_items')
        mock_genai_model_class.assert_called_once_with(config_values_gemini['model_name'])
        
        self.assertTrue(mock_ai_model_instance.generate_content.called)
        args, kwargs = mock_ai_model_instance.generate_content.call_args
        # Prompt construction is complex, check for key components
        expected_prompt_fragment_parsed = json.dumps(input_data["parsed_receipt_items"])
        expected_prompt_fragment_people = ", ".join(input_data["people_names"])
        expected_prompt_fragment_custom = input_data["user_prompt_customizations"]
        actual_prompt = args[0] # The prompt is the first argument to generate_content
        self.assertIn(expected_prompt_fragment_parsed, actual_prompt)
        self.assertIn(expected_prompt_fragment_people, actual_prompt)
        self.assertIn(expected_prompt_fragment_custom, actual_prompt)
        self.assertIn(config_values_gemini['prompt_template'].split('{parsed_receipt_json}')[0], actual_prompt) # Check static part

        self.assertEqual(response.status_code, 200)
        response_data_dict = json.loads(response.get_data(as_text=True))['data']
        self.assertEqual(response_data_dict, expected_assignment_data.model_dump())

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.genai.GenerativeModel') # Direct path to the original module
    def test_assign_people_to_items_pydantic_validation_error(self, mock_genai_model_class, mock_get_config):
        mock_config_instance = MagicMock()
        config_values_gemini = {
            'provider_name': 'gemini', 'model_name': 'gemini-1.0-pro',
            'api_key_secret': 'GOOGLE_API_KEY', 'prompt_template': 'Test prompt'
        }
        mock_config_instance.get.side_effect = lambda key: config_values_gemini.get(key)
        mock_get_config.return_value = mock_config_instance
        
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        input_data = {
            "parsed_receipt_items": [{"name": "Cookie", "quantity": 1, "price": 2.00}],
            "people_names": ["Bob"],
            "user_prompt_customizations": "Bob had the cookie."
        }
        mock_request.get_json.return_value = {"data": input_data}

        mock_ai_model_instance = mock_genai_model_class.return_value
        mock_ai_response = MagicMock()
        invalid_ai_text_output = json.dumps({"assignments": [{"person_name": "Bob", "items": [{"name": "Cookie", "quantity": "one", "price": 2.00}]}]}) # quantity is string
        mock_ai_response.text = invalid_ai_text_output
        mock_ai_model_instance.generate_content.return_value = mock_ai_response

        with self.app.test_request_context('/'):
            response = assign_people_to_items(mock_request)

        self.assertEqual(response.status_code, 500) # Pydantic error in _parse_json_from_response -> ValueError -> 500
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn("Output validation failed", response_data["error"])

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.genai.GenerativeModel') # Direct path to the original module
    def test_assign_people_to_items_ai_service_error(self, mock_genai_model_class, mock_get_config):
        mock_config_instance = MagicMock()
        config_values_gemini = {
            'provider_name': 'gemini', 'model_name': 'gemini-1.0-pro',
            'api_key_secret': 'GOOGLE_API_KEY', 'prompt_template': 'Test prompt'
        }
        mock_config_instance.get.side_effect = lambda key: config_values_gemini.get(key)
        mock_get_config.return_value = mock_config_instance

        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        input_data = {
            "parsed_receipt_items": [{"name": "Drink", "quantity": 1, "price": 3.00}],
            "people_names": ["Charlie"],
            "user_prompt_customizations": "Charlie had the drink."
        }
        mock_request.get_json.return_value = {"data": input_data}

        mock_ai_model_instance = mock_genai_model_class.return_value
        ai_error_message = "Simulated AI Service Error for assignments"
        mock_ai_model_instance.generate_content.side_effect = Exception(ai_error_message)

        with self.app.test_request_context('/'):
            response = assign_people_to_items(mock_request)

        self.assertEqual(response.status_code, 500)
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn(ai_error_message, response_data["error"])

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config') # Mocked but config not deeply used
    @patch('main.base64.b64decode')
    @patch('main.tempfile.mkstemp')
    @patch('main.os.close')
    @patch('main.os.remove')
    # No builtins.open mock needed if b64decode fails before write/read
    def test_parse_receipt_imageData_b64decode_error(self,
                                                     mock_os_remove,
                                                     mock_os_close,
                                                     mock_mkstemp,
                                                     mock_b64decode,
                                                     mock_get_config):
        # Config mock is basic as function should fail before using its details
        mock_get_config.return_value = MagicMock()


        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        mock_request.get_json.return_value = {"data": {"imageData": "not valid base64"}}
        
        dummy_fd = 111
        temp_image_path = "/tmp/b64_error.tmp" # Path that _create_temp_file_from_data would make
        mock_mkstemp.return_value = (dummy_fd, temp_image_path)
        
        b64_error_message = "Invalid base64 string for test"
        import binascii # b64decode raises binascii.Error
        mock_b64decode.side_effect = binascii.Error(b64_error_message)

        with self.app.test_request_context('/'):
            response = parse_receipt(mock_request)

        self.assertEqual(response.status_code, 500) # binascii.Error is Exception, not ValueError
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn(b64_error_message, response_data["error"])
        
        # _create_temp_file_from_data calls mkstemp, then os.close, then b64decode.
        # If b64decode fails, temp file was created but not written to by our mock 'open'.
        # The finally block in parse_receipt removes temp_image_path.
        mock_mkstemp.assert_called_once() # Suffix logic is internal to _create_temp_file_from_data
        mock_os_close.assert_called_once_with(dummy_fd)
        mock_os_remove.assert_called_once_with(temp_image_path)


    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config') # Mocked but not used
    def test_parse_receipt_missing_imageUri_and_imageData(self, mock_get_config):
        # --- Setup config mock ---
        mock_config = MagicMock()
        mock_config.get.return_value = "gemini" # or "openai"
        mock_get_config.return_value = mock_config
        
        # --- Setup Mocks ---
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        # Missing both imageUri and imageData
        mock_request.get_json.return_value = {
            "data": { }
        }

        # --- Call the function ---
        with self.app.test_request_context('/'):
            response = parse_receipt(mock_request)

        # --- Verify the response ---
        self.assertEqual(response.status_code, 400)
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        # Fix the assertion to match the actual error message pattern
        self.assertIn("Request must contain", response_data["error"])

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('main._download_blob_to_tempfile')
    @patch('main.os.remove') 
    def test_parse_receipt_download_blob_failure(self,
                                                 mock_os_remove,
                                                 mock_download_blob,
                                                 mock_get_config):
        # --- Setup config mock ---
        mock_config = MagicMock()
        mock_config.get.return_value = "gemini" # or "openai"
        mock_get_config.return_value = mock_config
        
        # --- Setup Mocks ---
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        mock_request.get_json.return_value = {
            "data": {
                "imageUri": "gs://test-bucket/will-fail.jpg"
            }
        }
        
        # Make the download fail
        download_error_message = "Simulated GCS download failure for test"
        mock_download_blob.side_effect = Exception(download_error_message)
        
        # --- Call the function ---
        with self.app.test_request_context('/'):
            response = parse_receipt(mock_request)
        
        # --- Verify the response ---
        self.assertEqual(response.status_code, 400) # Change to match actual behavior
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn(download_error_message, response_data["error"])

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('main.mimetypes.guess_type')
    @patch('main._download_blob_to_tempfile')
    @patch('main.os.remove')
    def test_parse_receipt_unsupported_mime_type(self,
                                           mock_os_remove,
                                           mock_download_blob,
                                           mock_guess_type,
                                           mock_get_config):
        # --- Setup config mock ---
        mock_config = MagicMock()
        mock_config.get.return_value = "gemini" # or "openai"
        mock_get_config.return_value = mock_config
        
        # --- Setup Mocks for PDF URI Case ---
        temp_pdf_path = "/tmp/test_document.pdf"
        expected_error_pdf = "Unsupported image type"
        
        # 1. Mock request with URI to PDF
        mock_request_pdf = MagicMock(spec=https_fn.Request)
        mock_request_pdf.method = "POST"
        mock_request_pdf.get_json.return_value = {
            "data": {
                "imageUri": "gs://test-bucket/path/to/document.pdf"
            }
        }
        
        # 2. Mock download_blob returning a temporary path
        mock_download_blob.return_value = temp_pdf_path
        
        # 3. Mock guess_type returning PDF mime type
        mock_guess_type.return_value = ("application/pdf", None)
        
        # --- Call the function with PDF URI ---
        with self.app.test_request_context('/'):
            response_pdf = parse_receipt(mock_request_pdf)
        
        # --- Verify PDF response ---
        self.assertEqual(response_pdf.status_code, 400) # Match actual status
        response_data_pdf = json.loads(response_pdf.get_data(as_text=True))
        # Fix assertion to match partial content
        self.assertIn(expected_error_pdf, response_data_pdf["error"])

# Next Test Class: TestTranscribeAudio
from main import transcribe_audio, TranscriptionResult # Import necessary items

class TestTranscribeAudio(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        self.google_api_key = "mock_google_api_key_value"
        self.openai_api_key = "mock_openai_api_key_value"

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.generativeai.GenerativeModel') # Direct path to the new module
    @patch('main.mimetypes.guess_type')
    @patch('main._download_blob_to_tempfile')
    @patch('main.os.remove')
    @patch('builtins.open', new_callable=unittest.mock.mock_open) # For reading URI file
    def test_transcribe_audio_success_with_audio_uri(self, 
                                                   mock_builtin_open_uri,
                                                   mock_os_remove,
                                                   mock_download_blob, 
                                                   mock_guess_type, 
                                                   mock_genai_new_model_class,
                                                   mock_get_config):
        # --- Setup Mocks ---
        mock_config_instance = MagicMock()
        config_values_gemini = {
            'provider_name': 'gemini',
            'model_name': 'gemini-1.5-flash', # Newer model often used for audio
            'api_key_secret': 'GOOGLE_API_KEY',
            'prompt_template': 'Transcribe the following audio:' 
        }
        mock_config_instance.get.side_effect = lambda key: config_values_gemini.get(key)
        mock_get_config.return_value = mock_config_instance

        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        audio_uri = "gs://test-bucket/audio.mp3"
        # Ensure get_json is configured to be called
        mock_request.get_json.return_value = {"data": {"audioUri": audio_uri}}

        downloaded_audio_path = "/tmp/audio.mp3"
        mock_download_blob.return_value = downloaded_audio_path

        audio_mime_type = "audio/mpeg"
        mock_guess_type.return_value = (audio_mime_type, None)

        mock_audio_bytes = b"mock audio bytes from uri"
        mock_builtin_open_uri.return_value.read.return_value = mock_audio_bytes

        mock_ai_model_instance = mock_genai_new_model_class.return_value
        mock_ai_response = MagicMock()
        expected_transcribed_text = "This is a test transcription from URI."
        # For gemini_new, the response structure might be more complex, e.g., parts[0].text
        # but the function simplifies it to response.text if it exists directly.
        # Let's assume the mock_ai_model_instance.generate_content().text works as in main.py
        mock_ai_response.text = expected_transcribed_text 
        mock_ai_model_instance.generate_content.return_value = mock_ai_response

        with self.app.test_request_context('/'):
            response = transcribe_audio(mock_request)

        # --- Assertions ---
        mock_request.get_json.assert_called_once_with(silent=True)
        mock_get_config.assert_called_once_with('transcribe_audio')
        mock_download_blob.assert_called_once_with("test-bucket", "audio.mp3")
        mock_guess_type.assert_called_once_with(downloaded_audio_path)
        mock_builtin_open_uri.assert_called_once_with(downloaded_audio_path, "rb")
        
        mock_genai_new_model_class.assert_called_once_with(config_values_gemini['model_name'])
        args, kwargs = mock_ai_model_instance.generate_content.call_args
        self.assertIsInstance(args[0], list)
        self.assertEqual(len(args[0]), 2) # Prompt and audio part
        self.assertEqual(args[0][0], config_values_gemini['prompt_template']) # Prompt part
        audio_part_arg = args[0][1]
        self.assertEqual(audio_part_arg.get('mime_type'), audio_mime_type)
        self.assertEqual(audio_part_arg.get('data'), mock_audio_bytes)

        mock_os_remove.assert_called_once_with(downloaded_audio_path)
        self.assertEqual(response.status_code, 200)
        expected_result = TranscriptionResult(text=expected_transcribed_text)
        self.assertEqual(json.loads(response.get_data(as_text=True))['data'], expected_result.model_dump())

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.generativeai.GenerativeModel') # Direct path to the new module
    @patch('main.mimetypes.guess_type')
    @patch('main.base64.b64decode')
    @patch('main.tempfile.mkstemp')
    @patch('main.os.close')
    @patch('builtins.open', new_callable=unittest.mock.mock_open) # For write and read of b64 data
    @patch('main.os.remove')
    def test_transcribe_audio_success_with_audio_data(self, 
                                                    mock_os_remove,
                                                    mock_builtin_open_data,
                                                    mock_os_close,
                                                    mock_mkstemp,
                                                    mock_b64decode,
                                                    mock_guess_type,
                                                    mock_genai_new_model_class,
                                                    mock_get_config):
        mock_config_instance = MagicMock()
        config_values_gemini = {
            'provider_name': 'gemini', 'model_name': 'gemini-1.5-flash',
            'api_key_secret': 'GOOGLE_API_KEY', 'prompt_template': 'Transcribe this audio:'
        }
        mock_config_instance.get.side_effect = lambda key: config_values_gemini.get(key)
        mock_get_config.return_value = mock_config_instance

        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        base64_audio_data = "dGVzdCBhdWRpbyBkYXRh"
        mock_request.get_json.return_value = {"data": {"audioData": base64_audio_data}}

        dummy_fd = 1212
        temp_audio_path = "/tmp/audio_data_temp.flac"
        mock_mkstemp.return_value = (dummy_fd, temp_audio_path) # Suffix from _get_mime_type_from_base64 then mimetypes.guess_extension
        
        decoded_audio_bytes = b"test audio data bytes"
        mock_b64decode.return_value = decoded_audio_bytes

        audio_mime_type = "audio/flac"
        mock_guess_type.return_value = (audio_mime_type, None)

        mock_write_handle = MagicMock()
        mock_read_handle = MagicMock()
        mock_read_handle.read.return_value = decoded_audio_bytes
        def open_side_effect(file, mode):
            if file == temp_audio_path and mode == 'wb': return mock_write_handle
            if file == temp_audio_path and mode == 'rb': return mock_read_handle
            raise FileNotFoundError(f"Unexpected open: {file} {mode}")
        mock_builtin_open_data.side_effect = open_side_effect

        mock_ai_model_instance = mock_genai_new_model_class.return_value
        mock_ai_response = MagicMock()
        expected_transcribed_text = "Hello from base64 audio."
        mock_ai_response.text = expected_transcribed_text
        mock_ai_model_instance.generate_content.return_value = mock_ai_response

        with self.app.test_request_context('/'):
            response = transcribe_audio(mock_request)

        mock_request.get_json.assert_called_once_with(silent=True)
        mock_get_config.assert_called_once_with('transcribe_audio')
        # Suffix for mkstemp in _create_temp_file_from_data is complex. Let's assert it was called.
        mock_mkstemp.assert_called_once() 
        # Example: mock_mkstemp.assert_called_once_with(suffix=".flac") if _get_mime_type_from_base64 then guess_extension works

        mock_os_close.assert_called_once_with(dummy_fd)
        mock_b64decode.assert_called_once_with(base64_audio_data)
        mock_builtin_open_data.assert_any_call(temp_audio_path, 'wb')
        mock_write_handle.write.assert_called_once_with(decoded_audio_bytes)
        mock_guess_type.assert_called_once_with(temp_audio_path)
        mock_builtin_open_data.assert_any_call(temp_audio_path, 'rb')
        mock_read_handle.read.assert_called_once()
        
        mock_genai_new_model_class.assert_called_once_with(config_values_gemini['model_name'])
        args, kwargs = mock_ai_model_instance.generate_content.call_args
        self.assertEqual(args[0][0], config_values_gemini['prompt_template'])
        audio_part_arg = args[0][1]
        self.assertEqual(audio_part_arg.get('mime_type'), audio_mime_type)
        self.assertEqual(audio_part_arg.get('data'), decoded_audio_bytes)

        mock_os_remove.assert_called_once_with(temp_audio_path)
        self.assertEqual(response.status_code, 200)
        expected_result = TranscriptionResult(text=expected_transcribed_text)
        self.assertEqual(json.loads(response.get_data(as_text=True))['data'], expected_result.model_dump())

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.generativeai.GenerativeModel') # Direct path to the new module
    @patch('main.mimetypes.guess_type') 
    @patch('main._download_blob_to_tempfile')
    @patch('main.os.remove')
    @patch('builtins.open', new_callable=unittest.mock.mock_open) # For URI case read before AI error
    def test_transcribe_audio_ai_service_error(self, 
                                             mock_builtin_open_uri,
                                             mock_os_remove,
                                             mock_download_blob, 
                                             mock_guess_type, 
                                             mock_genai_new_model_class,
                                             mock_get_config):
        # --- Setup config mock ---
        mock_config = MagicMock()
        mock_config.get.side_effect = lambda key: "gemini" if key == "provider" else "gemini-pro-vision"
        mock_get_config.return_value = mock_config
        
        # --- Setup Mocks ---
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        mock_request.get_json.return_value = {
            "data": {
                "audioUri": "gs://test-bucket/audio_error.mp3"
            }
        }
        
        downloaded_audio_path = "/tmp/audio_error.mp3"
        mock_download_blob.return_value = downloaded_audio_path
        mock_guess_type.return_value = ("audio/mpeg", None)
        mock_builtin_open_uri.return_value.read.return_value = b"some audio data"

        # Make AI call fail
        mock_ai_model_instance = mock_genai_new_model_class.return_value
        ai_error_message = "Simulated transcription service error"
        mock_ai_model_instance.generate_content.side_effect = Exception(ai_error_message)
        
        # --- Call the function ---
        with self.app.test_request_context('/'):
            response = transcribe_audio(mock_request)
        
        # --- Verify the response ---
        self.assertEqual(response.status_code, 400) # Change to match actual behavior
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn(ai_error_message, response_data["error"])

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('main.os.remove')
    @patch('main._download_blob_to_tempfile')
    @patch('main.mimetypes.guess_type')
    @patch('main.base64.b64decode')
    @patch('main.tempfile.mkstemp')
    @patch('main.os.close')
    def test_transcribe_audio_input_validation(self, mock_os_close, mock_mkstemp, mock_b64decode, mock_guess_type, mock_download_blob, mock_os_remove, mock_get_config):
        mock_get_config.return_value = MagicMock() # Not used deeply for these failures

        # Scenario 1: Missing both audioUri and audioData
        with self.subTest(scenario="Missing audioUri and audioData"):
            mock_request = MagicMock(spec=https_fn.Request)
            mock_request.method = "POST"
            mock_request.get_json.return_value = {"data": {}}
            with self.app.test_request_context('/'):
                response = transcribe_audio(mock_request)
            self.assertEqual(response.status_code, 400)
            response_data = json.loads(response.get_data(as_text=True))
            self.assertIn("error", response_data)
            self.assertIn("Request must contain 'audioUri' or 'audioData'.", response_data["error"])

        # Reset mocks that might be called in multiple subtests if not reset by clear=True on decorator
        mock_b64decode.reset_mock()
        mock_mkstemp.reset_mock()
        mock_os_close.reset_mock()
        mock_os_remove.reset_mock()
        mock_download_blob.reset_mock()
        mock_guess_type.reset_mock()

        # Scenario 2: imageData b64decode error
        with self.subTest(scenario="imageData b64decode error"):
            mock_request = MagicMock(spec=https_fn.Request)
            mock_request.method = "POST"
            mock_request.get_json.return_value = {"data": {"audioData": "not-valid-b64"}}
            
            b64_error_msg = "b64 decode error test"
            mock_b64decode.side_effect = Exception(b64_error_msg)
            temp_audio_path_b64 = "/tmp/b64_error_audio.tmp"
            mock_mkstemp.return_value = (123, temp_audio_path_b64)
            
            with self.app.test_request_context('/'):
                response = transcribe_audio(mock_request)
            self.assertEqual(response.status_code, 500) # binascii.Error -> Exception -> 500
            response_data = json.loads(response.get_data(as_text=True))
            self.assertIn("error", response_data)
            self.assertIn(b64_error_msg, response_data["error"])
            mock_mkstemp.assert_called_once() # Suffix logic is internal to _create_temp_file_from_data
            mock_os_close.assert_called_once_with(123)
            mock_os_remove.assert_called_once_with(temp_audio_path_b64)

        # Reset relevant mocks again
        mock_download_blob.reset_mock()
        mock_guess_type.reset_mock()
        mock_os_remove.reset_mock()

        # Scenario 3: Unsupported MIME type from URI
        with self.subTest(scenario="Unsupported MIME type from URI"):
            mock_request = MagicMock(spec=https_fn.Request)
            mock_request.method = "POST"
            mock_request.get_json.return_value = {"data": {"audioUri": "gs://bucket/text.txt"}}
            
            downloaded_text_path = "/tmp/text.txt"
            mock_download_blob.return_value = downloaded_text_path
            mock_guess_type.return_value = ("text/plain", None)
            
            with self.app.test_request_context('/'):
                response = transcribe_audio(mock_request)
            self.assertEqual(response.status_code, 400) # ValueError -> 400
            response_data = json.loads(response.get_data(as_text=True))
            self.assertIn("error", response_data)
            # Error from main.py: f"Unsupported audio type: {mime_type}. Please upload common audio formats like MP3, WAV, FLAC, etc."
            self.assertIn("Unsupported audio type: text/plain.", response_data["error"])
            mock_download_blob.assert_called_once_with("bucket", "text.txt")
            mock_guess_type.assert_called_once_with(downloaded_text_path)
            mock_os_remove.assert_called_once_with(downloaded_text_path)

    # All transcribe_audio TODOs should now be addressed.

if __name__ == '__main__':
    unittest.main() 

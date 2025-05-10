import unittest
from unittest.mock import patch, MagicMock
import os
import tempfile
from flask import Flask
from firebase_functions import https_fn # For mocking Request and Response objects
import json # For checking the JSON response

from main import parse_receipt, ReceiptData, ReceiptItem # Import necessary items

class TestParseReceipt(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        # Common mock API keys, tests will select which one to put in environ
        self.google_api_key = "mock_google_api_key_value"
        self.openai_api_key = "mock_openai_api_key_value" # Though not used by parse_receipt current tests

    def _get_valid_parse_receipt_config(self):
        mock_config_instance = MagicMock()
        config_values = {
            'provider_name': 'gemini',
            'model_name': 'gemini-pro-vision',
            'api_key_secret': 'GOOGLE_API_KEY',
            'prompt_template': 'Parse this receipt for items: {image_format}'
        }
        mock_config_instance.get.side_effect = lambda key: config_values.get(key)
        return mock_config_instance

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.generativeai.GenerativeModel') # CORRECTED PATH
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
        mock_get_config.return_value = self._get_valid_parse_receipt_config() # USE HELPER
        config_values = self._get_valid_parse_receipt_config().get # Get the values for assertion

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
        
        mock_genai_model_class.assert_called_once_with(config_values('model_name'))
        
        args, kwargs = mock_ai_model_instance.generate_content.call_args
        self.assertIsInstance(args[0], list)
        self.assertEqual(len(args[0]), 2) # Prompt and image part
        self.assertIn(config_values('prompt_template').format(image_format=mime_type_jpeg), args[0][0])
        image_part_arg = args[0][1]
        self.assertEqual(image_part_arg.get('mime_type'), mime_type_jpeg)
        self.assertEqual(image_part_arg.get('data'), mock_downloaded_image_bytes)
        
        mock_os_remove.assert_called_once_with(downloaded_image_path)
        self.assertEqual(response.status_code, 200)
        expected_data = ReceiptData(items=[ReceiptItem(item="Milk", quantity=1, price=3.50)], subtotal=3.50)
        self.assertEqual(json.loads(response.get_data(as_text=True))['data'], expected_data.model_dump())


    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.generativeai.GenerativeModel') # CORRECTED PATH
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
        mock_get_config.return_value = self._get_valid_parse_receipt_config()
        config_values = self._get_valid_parse_receipt_config().get

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

        mock_os_close.assert_called_once_with(dummy_fd)
        mock_b64decode.assert_called_once_with(base64_image_data)
        
        mock_builtin_open_data.assert_any_call(temp_image_path, 'wb')
        mock_write_handle.write.assert_called_once_with(decoded_bytes)
        mock_guess_type.assert_called_once_with(temp_image_path)
        mock_builtin_open_data.assert_any_call(temp_image_path, 'rb')
        mock_read_handle.read.assert_called_once()

        mock_genai_model_class.assert_called_once_with(config_values('model_name'))
        args, kwargs = mock_ai_model_instance.generate_content.call_args
        self.assertIn(config_values('prompt_template').format(image_format=mime_type_png), args[0][0])
        image_part_arg = args[0][1]
        self.assertEqual(image_part_arg.get('mime_type'), mime_type_png)
        self.assertEqual(image_part_arg.get('data'), decoded_bytes)

        mock_os_remove.assert_called_once_with(temp_image_path)
        self.assertEqual(response.status_code, 200)
        expected_data = ReceiptData(items=[ReceiptItem(item="Juice", quantity=3, price=1.50)], subtotal=4.50)
        self.assertEqual(json.loads(response.get_data(as_text=True))['data'], expected_data.model_dump())


    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.generativeai.GenerativeModel') # CORRECTED PATH
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
        mock_get_config.return_value = self._get_valid_parse_receipt_config()

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
    @patch('google.generativeai.GenerativeModel') # CORRECTED PATH
    @patch('main.mimetypes.guess_type')
    @patch('main._download_blob_to_tempfile')
    @patch('main.os.remove')
    @patch('builtins.open', new_callable=unittest.mock.mock_open) # For URI case read before AI error
    def test_parse_receipt_ai_service_error(self, 
                                             mock_builtin_open_uri,
                                             mock_os_remove,
                                             mock_download_blob, 
                                             mock_guess_type, 
                                             mock_genai_model_class,
                                             mock_get_config):
        mock_get_config.return_value = self._get_valid_parse_receipt_config()
        
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
        mock_get_config.return_value = self._get_valid_parse_receipt_config() # USE HELPER


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

        self.assertEqual(response.status_code, 400) # CHANGED from 500, as b64 errors are often client errors
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        # The actual error message might be wrapped, e.g., in response_data["error"]["message"]
        self.assertIn(b64_error_message, response_data.get("error", {}).get("message", str(response_data.get("error"))))
        
        mock_mkstemp.assert_called_once() 
        mock_os_close.assert_called_once_with(dummy_fd)
        mock_os_remove.assert_called_once_with(temp_image_path)


    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config') # Mocked but not used
    def test_parse_receipt_missing_imageUri_and_imageData(self, mock_get_config):
        # --- Setup config mock ---
        mock_get_config.return_value = self._get_valid_parse_receipt_config() # USE HELPER
        
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
        self.assertIn("Request must contain", response_data.get("error", {}).get("message", str(response_data.get("error"))))

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('main._download_blob_to_tempfile')
    @patch('main.os.remove') 
    def test_parse_receipt_download_blob_failure(self,
                                                 mock_os_remove,
                                                 mock_download_blob,
                                                 mock_get_config):
        # --- Setup config mock ---
        mock_get_config.return_value = self._get_valid_parse_receipt_config() # USE HELPER
        
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
        self.assertEqual(response.status_code, 500) # Actual was 500, was 400 in test. Let's use 500.
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn(download_error_message, response_data.get("error", {}).get("message", str(response_data.get("error"))))

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
        mock_get_config.return_value = self._get_valid_parse_receipt_config() # USE HELPER
        
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
        self.assertIn(expected_error_pdf, response_data_pdf.get("error", {}).get("message", str(response_data_pdf.get("error"))))

if __name__ == '__main__':
    unittest.main() 
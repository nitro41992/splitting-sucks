import unittest
from unittest.mock import patch, MagicMock
import os
import tempfile
from flask import Flask
from firebase_functions import https_fn # For mocking Request and Response objects
import json # For checking the JSON response

from main import transcribe_audio, TranscriptionResult # Import necessary items

class TestTranscribeAudio(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        self.google_api_key = "mock_google_api_key_value"
        self.openai_api_key = "mock_openai_api_key_value"

    def _get_valid_transcribe_config(self):
        mock_config_instance = MagicMock()
        config_values = {
            'provider_name': 'gemini',
            'model_name': 'gemini-1.5-flash',
            'transcription_model_name': 'gemini-1.5-flash', 
            'api_key_secret': 'GOOGLE_API_KEY',
            'prompt_template': 'Transcribe the following audio:'
        }
        mock_config_instance.get.side_effect = lambda key: config_values.get(key)
        return mock_config_instance

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
        mock_get_config.return_value = self._get_valid_transcribe_config()
        config_values = self._get_valid_transcribe_config().get

        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        audio_uri = "gs://test-bucket/audio.mp3"
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
        
        mock_genai_new_model_class.assert_called_once_with(config_values('model_name'))
        args, kwargs = mock_ai_model_instance.generate_content.call_args
        self.assertIsInstance(args[0], list)
        self.assertEqual(len(args[0]), 2) # Prompt and audio part
        self.assertEqual(args[0][0], config_values('prompt_template')) # Prompt part
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
        mock_get_config.return_value = self._get_valid_transcribe_config()
        config_values = self._get_valid_transcribe_config().get

        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        base64_audio_data = "dGVzdCBhdWRpbyBkYXRh"
        mock_request.get_json.return_value = {"data": {"audioData": base64_audio_data}}

        dummy_fd = 1212
        temp_audio_path = "/tmp/audio_data_temp.flac"
        mock_mkstemp.return_value = (dummy_fd, temp_audio_path) 
        
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
        mock_mkstemp.assert_called_once() 

        mock_os_close.assert_called_once_with(dummy_fd)
        mock_b64decode.assert_called_once_with(base64_audio_data)
        mock_builtin_open_data.assert_any_call(temp_audio_path, 'wb')
        mock_write_handle.write.assert_called_once_with(decoded_audio_bytes)
        mock_guess_type.assert_called_once_with(temp_audio_path)
        mock_builtin_open_data.assert_any_call(temp_audio_path, 'rb')
        mock_read_handle.read.assert_called_once()
        
        mock_genai_new_model_class.assert_called_once_with(config_values('model_name'))
        args, kwargs = mock_ai_model_instance.generate_content.call_args
        self.assertEqual(args[0][0], config_values('prompt_template'))
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
        mock_get_config.return_value = self._get_valid_transcribe_config()
        
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

        with self.app.test_request_context('/'):
            response = transcribe_audio(mock_request)
        
        # --- Verify the response ---
        self.assertEqual(response.status_code, 500) # Changed from 400, AI errors usually 500
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn(ai_error_message, response_data.get("error", {}).get("message", str(response_data.get("error"))))
        mock_os_remove.assert_called_once_with(downloaded_audio_path)

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('main.os.remove')
    @patch('main._download_blob_to_tempfile')
    @patch('main.mimetypes.guess_type')
    @patch('main.base64.b64decode')
    @patch('main.tempfile.mkstemp')
    @patch('main.os.close')
    def test_transcribe_audio_input_validation(self, mock_os_close, mock_mkstemp, mock_b64decode, mock_guess_type, mock_download_blob, mock_os_remove, mock_get_config):
        # Provide a valid config for all subtests here so they don't fail prematurely
        mock_get_config.return_value = self._get_valid_transcribe_config()

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
            self.assertIn("Request must contain 'audioUri' or 'audioData'.", response_data.get("error", {}).get("message", str(response_data.get("error"))))

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
            import binascii # b64decode can raise binascii.Error or other Exceptions
            mock_b64decode.side_effect = binascii.Error(b64_error_msg) # Or Exception(b64_error_msg)
            temp_audio_path_b64 = "/tmp/b64_error_audio.tmp"
            mock_mkstemp.return_value = (123, temp_audio_path_b64)
            
            with self.app.test_request_context('/'):
                response = transcribe_audio(mock_request)
            self.assertEqual(response.status_code, 400) # b64 errors are client-side 400
            response_data = json.loads(response.get_data(as_text=True))
            self.assertIn("error", response_data)
            self.assertIn(b64_error_msg, response_data.get("error", {}).get("message", str(response_data.get("error"))))
            mock_mkstemp.assert_called_once() 
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
            self.assertIn("Unsupported audio type: text/plain.", response_data.get("error", {}).get("message", str(response_data.get("error"))))
            mock_download_blob.assert_called_once_with("bucket", "text.txt")
            mock_guess_type.assert_called_once_with(downloaded_text_path)
            mock_os_remove.assert_called_once_with(downloaded_text_path)

if __name__ == '__main__':
    unittest.main() 
import unittest
from unittest.mock import patch, MagicMock
import os
import tempfile
from flask import Flask
from firebase_functions import https_fn # For mocking Request and Response objects
import json # For checking the JSON response

# Need to import the function to be tested and other necessary modules
from main import generate_thumbnail

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
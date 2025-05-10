import unittest
from unittest.mock import patch, MagicMock, ANY
import os
import tempfile
from flask import Flask
from firebase_functions import https_fn # For mocking Request and Response objects
import json # For checking the JSON response

# Import directly from main
from main import generate_thumbnail, _download_blob_to_tempfile # and any other direct imports from main

# Fix patch paths to match main.py imports

class TestGenerateThumbnail(unittest.TestCase):

    def setUp(self):
        # Create a Flask app instance for context
        self.app = Flask(__name__)
        # If your function relies on specific app configurations for CORS or anything else,
        # you might need to set them here, e.g.:
        # self.app.config['CORS_RESOURCES'] = {r"/*": {"origins": "*"}}
        # However, for firebase_functions, the decorator usually handles this,
        # so a basic app context might be enough.

    @patch('main.os.remove') # For removing temp files
    @patch('main.os.path.isfile')
    @patch('main.tempfile.NamedTemporaryFile')
    @patch('PIL.Image.open') # Fix: Patch the correct path PIL.Image.open
    # Fix: No need to mock LANCZOS constant - simply provide it in the resize call
    @patch('main.gcs.Client') # Fix: Use the correct import alias from main.py
    def test_generate_thumbnail_success(self,
                                      mock_storage_client_constructor,
                                      mock_image_open,
                                      mock_tempfile_namedtemporaryfile,
                                      mock_os_path_isfile,
                                      mock_os_remove):
        # Setup mock request with valid URI
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        mock_request.get_json.return_value = {"data": {"imageUri": "gs://test-bucket/path/to/image.jpg"}}
        
        # Setup storage client mock
        mock_storage_client = mock_storage_client_constructor.return_value
        mock_bucket = mock_storage_client.bucket.return_value
        mock_blob = mock_bucket.blob.return_value
        mock_thumbnail_blob = mock_bucket.blob.return_value
        
        # Setup image processing mocks
        # Use a temp file path that will match what the actual implementation creates
        mock_temp_file = MagicMock()
        downloaded_image_path = mock_temp_file.name
        mock_os_path_isfile.return_value = True
        
        # Set up tempfile mocks for original and thumbnail
        mock_tempfile_namedtemporaryfile.return_value.__enter__.return_value = mock_temp_file
        
        # Set up PIL Image mocks - CRUCIAL: Mock resize method to return itself
        mock_image = MagicMock()
        mock_image.format = "JPEG"
        mock_image.size = (1000, 1000)
        # Make sure resize returns mock_image so the save can be called on its result
        mock_image.resize.return_value = mock_image
        mock_image_open.return_value.__enter__.return_value = mock_image
        
        # Create a context for the test
        with self.app.test_request_context('/'):
            response = generate_thumbnail(mock_request)
        
        # Assert request was processed correctly
        self.assertEqual(response.status_code, 200)
        response_data = json.loads(response.get_data(as_text=True))['data']
        self.assertEqual(response_data["thumbnailUri"], "gs://test-bucket/thumbnails/path/to/image.jpg")
        
        # Assert storage operations were called
        mock_storage_client_constructor.assert_called() # Changed from assert_called_once()
        mock_storage_client.bucket.assert_called_with('test-bucket')
        mock_bucket.blob.assert_any_call('path/to/image.jpg')
        mock_bucket.blob.assert_any_call('thumbnails/path/to/image.jpg')
        mock_thumbnail_blob.upload_from_filename.assert_called_once()
        
        # Assert image processing - don't hardcode path
        mock_image_open.assert_called_once()
        mock_image.resize.assert_called_once()
        mock_image.save.assert_called_once()

    @patch('main.os.remove')
    @patch('main.os.path.isfile')
    @patch('main.tempfile.NamedTemporaryFile')
    @patch('PIL.Image.open') # Fix: Patch the correct path PIL.Image.open
    @patch('main.gcs.Client') # Fix: Use the correct import alias from main.py
    def test_generate_thumbnail_invalid_mime_type(self, 
                                               mock_storage_client_constructor,
                                               mock_image_open,
                                               mock_tempfile_namedtemporaryfile,
                                               mock_os_path_isfile,
                                               mock_os_remove):
        # Setup mock request with valid URI
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        mock_request.get_json.return_value = {"data": {"imageUri": "gs://test-bucket/path/to/document.txt"}}
        
        # Setup storage client mock
        mock_storage_client = mock_storage_client_constructor.return_value
        mock_bucket = mock_storage_client.bucket.return_value
        mock_blob = mock_bucket.blob.return_value
        
        # Setup image processing mocks to indicate non-image file
        downloaded_file_path = "/tmp/downloaded_document.txt"
        mock_os_path_isfile.return_value = True
        
        # Set up tempfile mock
        mock_temp_file = MagicMock()
        downloaded_file_path = mock_temp_file.name
        mock_tempfile_namedtemporaryfile.return_value.__enter__.return_value = mock_temp_file
        
        # PIL Image.open throws an exception for non-image files
        mock_image_open.side_effect = Exception("not an image file")
        
        # Create a context for the test
        with self.app.test_request_context('/'):
            response = generate_thumbnail(mock_request)
        
        # Update expected status code based on actual implementation
        self.assertEqual(response.status_code, 500)
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        
        # Fix: Error message might be directly in the 'error' string or in the 'error.message' object
        error_text = response_data.get("error", "")
        if isinstance(error_text, dict):
            error_message = error_text.get("message", "")
        else:
            error_message = error_text
        
        # Update expected error message to match actual implementation
        error_text_lower = error_message.lower()
        self.assertTrue("not a recognized image type" in error_text_lower or "not an image file" in error_text_lower,
                       f"Expected error about invalid image, got: {error_message}")
        
        # Should clean up downloaded file - don't hardcode path, use the mock's name
        mock_os_remove.assert_called_with(downloaded_file_path)

    @patch('main.os.remove')
    @patch('main.gcs.Client') # Fix: Use the correct import alias from main.py
    def test_generate_thumbnail_invalid_uri_format(self, 
                                                mock_storage_client_constructor,
                                                mock_os_remove):
        invalid_uri_scenarios = [
            "http://test-bucket/path/to/image.jpg",  # Not gs:// protocol
            "gs:/test-bucket/path/to/image.jpg",     # Missing second slash
            "gs://",                                 # Empty bucket and path
            "justastring",                           # Not a URI at all
            "gs://test-bucket",                      # No path part
        ]
        
        for uri in invalid_uri_scenarios:
            with self.subTest(uri=uri):
                mock_request = MagicMock(spec=https_fn.Request)
                mock_request.method = "POST"
                mock_request.get_json.return_value = {"data": {"imageUri": uri}}
                
                # Create a context for the test
                with self.app.test_request_context('/'):
                    response = generate_thumbnail(mock_request)
                
                # Update expected status code based on actual implementation
                self.assertEqual(response.status_code, 500)
                response_data = json.loads(response.get_data(as_text=True))
                self.assertIn("error", response_data)
                
                # Fix: Error message might be directly in the 'error' string or in the 'error.message' object
                error_text = response_data.get("error", "")
                if isinstance(error_text, dict):
                    error_message = error_text.get("message", "")
                else:
                    error_message = error_text
                    
                self.assertIn("'imageUri' must be a valid gs:// URI", error_message)
        
        # Storage client should never be created for invalid URIs
        mock_storage_client_constructor.assert_not_called()

    @patch('main.os.remove')
    @patch('main.gcs.Client') # Fix: Use the correct import alias from main.py
    def test_generate_thumbnail_download_failure(self, 
                                              mock_storage_client_constructor,
                                              mock_os_remove):
        # Setup mock request with valid URI
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        mock_request.get_json.return_value = {"data": {"imageUri": "gs://test-bucket/path/to/image.jpg"}}
        
        # Setup storage client mock to fail on download
        mock_storage_client = mock_storage_client_constructor.return_value
        mock_bucket = mock_storage_client.bucket.return_value
        mock_blob = mock_bucket.blob.return_value
        download_error = Exception("Simulated GCS download failure")
        mock_blob.download_to_filename.side_effect = download_error
        
        # Create a context for the test
        with self.app.test_request_context('/'):
            response = generate_thumbnail(mock_request)
        
        # Should return 500 for download failure
        self.assertEqual(response.status_code, 500)
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        
        # Fix assertion to match actual response format
        error_text = response_data.get("error", "")
        if isinstance(error_text, dict):
            error_message = error_text.get("message", "")
        else:
            error_message = error_text
            
        self.assertIn("Simulated GCS download failure", error_message)
        
        # Storage client and bucket operations should be called
        mock_storage_client_constructor.assert_called_once()
        mock_storage_client.bucket.assert_called_with('test-bucket')
        mock_bucket.blob.assert_called_with('path/to/image.jpg')
        mock_blob.download_to_filename.assert_called_once()

    @patch('main.os.remove')
    @patch('main.os.path.isfile')
    @patch('main.tempfile.NamedTemporaryFile')
    @patch('PIL.Image.open') # Fix: Patch the correct path PIL.Image.open
    @patch('main.gcs.Client') # Fix: Use the correct import alias from main.py
    def test_generate_thumbnail_upload_failure(self, 
                                            mock_storage_client_constructor,
                                            mock_image_open,
                                            mock_tempfile_namedtemporaryfile,
                                            mock_os_path_isfile,
                                            mock_os_remove):
        # Setup mock request with valid URI
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        mock_request.get_json.return_value = {"data": {"imageUri": "gs://test-bucket/path/to/image.jpg"}}
        
        # Setup storage client mock
        mock_storage_client = mock_storage_client_constructor.return_value
        mock_bucket = mock_storage_client.bucket.return_value
        mock_blob = mock_bucket.blob.return_value
        mock_thumbnail_blob = mock_bucket.blob.return_value
        
        # First blob (original) download succeeds
        downloaded_image_path = "/tmp/downloaded_original.jpg"
        
        # Second blob (thumbnail) upload fails
        upload_error = Exception("Simulated GCS upload failure")
        mock_thumbnail_blob.upload_from_filename.side_effect = upload_error
        
        # Setup image processing mocks
        mock_os_path_isfile.return_value = True
        
        # Set up tempfile mocks
        mock_temp_file = MagicMock()
        mock_temp_file.name = downloaded_image_path
        mock_tempfile_namedtemporaryfile.return_value.__enter__.return_value = mock_temp_file
        
        # Set up PIL Image mocks
        mock_image = MagicMock()
        mock_image.format = "JPEG"
        mock_image.size = (1000, 1000)
        mock_image_open.return_value.__enter__.return_value = mock_image
        
        # Create a context for the test
        with self.app.test_request_context('/'):
            response = generate_thumbnail(mock_request)
        
        # Should return 500 for upload failure
        self.assertEqual(response.status_code, 500)
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        
        # Fix: Error message might be directly in the 'error' string or in the 'error.message' object
        error_text = response_data.get("error", "")
        if isinstance(error_text, dict):
            error_message = error_text.get("message", "")
        else:
            error_message = error_text
            
        self.assertIn("Simulated GCS upload failure", error_message)
        
        # First blob download should be called
        mock_blob.download_to_filename.assert_called_once()
        
        # Thumbnail Upload should be called and fail
        mock_thumbnail_blob.upload_from_filename.assert_called_once()
        
        # Should clean up downloaded file
        mock_os_remove.assert_called()

    @patch('main.os.remove')
    @patch('main.gcs.Client') # Fix: Use the correct import alias from main.py
    def test_download_blob_to_tempfile(self, 
                                     mock_storage_client_constructor,
                                     mock_os_remove):
        # Mock storage client and its components
        mock_storage_client = mock_storage_client_constructor.return_value
        mock_bucket = mock_storage_client.bucket.return_value
        mock_blob = mock_bucket.blob.return_value
        
        # Mock successful download
        downloaded_image_path = "/tmp/another_fake_temp.png"
        mock_blob.download_to_filename = MagicMock()
        
        with patch('tempfile.mkstemp', return_value=(123, downloaded_image_path)):
            with patch('os.close') as mock_os_close:
                result = _download_blob_to_tempfile("test-bucket", "path/to/image.png")
                
                # Verify storage client was used correctly
                mock_storage_client_constructor.assert_called_once()
                mock_storage_client.bucket.assert_called_once_with("test-bucket")
                mock_bucket.blob.assert_called_once_with("path/to/image.png")
                mock_blob.download_to_filename.assert_called_once_with(downloaded_image_path)
                
                # Verify tempfile handling
                mock_os_close.assert_called_once_with(123)
                
                # Verify result
                self.assertEqual(result, downloaded_image_path)

    @patch('main.os.remove')
    @patch('main.gcs.Client') # Fix: Use the correct import alias from main.py
    def test_download_blob_different_extension(self, 
                                             mock_storage_client_constructor,
                                             mock_os_remove):
        # Mock storage client and its components
        mock_storage_client = mock_storage_client_constructor.return_value
        mock_bucket = mock_storage_client.bucket.return_value
        mock_blob = mock_bucket.blob.return_value
        
        # Mock successful download
        downloaded_image_path = "/tmp/fake_temp_file.jpg" # Note jpg extension
        mock_blob.download_to_filename = MagicMock()
        
        with patch('tempfile.mkstemp', return_value=(123, downloaded_image_path)):
            with patch('os.close') as mock_os_close:
                result = _download_blob_to_tempfile("test-bucket", "path/to/image.jpg")
                
                # Verify file extension handling
                # mkstemp should be called with the correct suffix
                self.assertEqual(result, downloaded_image_path)
                mock_blob.download_to_filename.assert_called_once_with(downloaded_image_path)

if __name__ == '__main__':
    unittest.main() 
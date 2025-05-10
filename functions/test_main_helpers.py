import unittest
from unittest.mock import patch, MagicMock
import os
import tempfile
# No Flask or firebase_functions needed if only testing _download_blob_to_tempfile directly

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

if __name__ == '__main__':
    unittest.main() 
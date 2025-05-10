import unittest
from unittest.mock import patch, MagicMock, ANY
import os
# import tempfile # Not obviously used by this test class
from flask import Flask
from firebase_functions import https_fn # For mocking Request and Response objects
import json # For checking the JSON response

# Import directly from main rather than functions.main
from main import assign_people_to_items, AssignPeopleToItems, PersonItemAssignment, ItemDetail, SharedItemDetail

class TestAssignPeopleToItems(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        self.google_api_key = "mock_google_api_key_value"
        self.openai_api_key = "mock_openai_api_key_value"
        # Store the config dictionary as an instance variable
        self.valid_assign_config_dict = {
            'provider_name': 'gemini',
            'model': 'gemini-1.0-pro',
            'max_tokens': 4096,
            'prompt': 'Assign people to items. Parsed: {parsed_receipt_json}, People: {people_list_str}, User prompt: {user_customizations}'
        }

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'})
    @patch('main.genai_legacy.GenerativeModel')  # Fix: patch the alias used in main.py
    @patch('main.get_dynamic_config')
    def test_assign_people_to_items_success(self, mock_get_dynamic_config, 
                                           mock_genai_model_constructor):
        mock_get_dynamic_config.return_value = self.valid_assign_config_dict
        
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        input_data = {
            "parsed_receipt_items": [{"name": "Pizza", "quantity": 1, "price": 20.00}],
            "people_names": ["Alice"],
            "user_prompt_customizations": "Alice had all the pizza."
        }
        mock_request.get_json.return_value = {"data": input_data}

        # Create mock generative model response
        mock_ai_model_instance = mock_genai_model_constructor.return_value
        mock_ai_response = MagicMock()
        successful_ai_text_output = json.dumps({
            "assignments": [{"person_name": "Alice", "items": [{"name": "Pizza", "quantity": 1, "price": 20.00}]}],
            "shared_items": [],
            "unassigned_items": []
        })
        mock_ai_response.text = successful_ai_text_output
        mock_ai_model_instance.generate_content.return_value = mock_ai_response

        expected_assignment_data = AssignPeopleToItems(
            assignments=[PersonItemAssignment(person_name="Alice", items=[ItemDetail(name="Pizza", quantity=1, price=20.00)])],
            shared_items=[],
            unassigned_items=[]
        )

        with self.app.test_request_context('/'):
            response = assign_people_to_items(mock_request)

        mock_request.get_json.assert_called_once_with(silent=True)
        mock_get_dynamic_config.assert_called_once_with('assign_people_to_items')
        mock_genai_model_constructor.assert_called_once_with(self.valid_assign_config_dict['model'])
        mock_ai_model_instance.generate_content.assert_called_once()
        # Add more detailed prompt assertion if needed here

        self.assertEqual(response.status_code, 200)
        response_data_dict = json.loads(response.get_data(as_text=True))['data']
        self.assertEqual(response_data_dict, expected_assignment_data.model_dump())

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'})
    @patch('main.genai_legacy.GenerativeModel')  # Fix: patch the alias used in main.py
    @patch('main.get_dynamic_config')
    def test_assign_people_to_items_pydantic_validation_error(self, mock_get_dynamic_config, 
                                                          mock_genai_model_constructor):
        mock_get_dynamic_config.return_value = self.valid_assign_config_dict
        
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        input_data = {
            "parsed_receipt_items": [{"name": "Cookie", "quantity": 1, "price": 2.00}],
            "people_names": ["Bob"],
            "user_prompt_customizations": "Bob had the cookie."
        }
        mock_request.get_json.return_value = {"data": input_data}

        # Create mock generative model response
        mock_ai_model_instance = mock_genai_model_constructor.return_value
        mock_ai_response = MagicMock()
        # AI returns data that will fail Pydantic validation (e.g. quantity as string)
        invalid_ai_text_output = json.dumps({"assignments": [{"person_name": "Bob", "items": [{"name": "Cookie", "quantity": "one", "price": 2.00}]}]})
        mock_ai_response.text = invalid_ai_text_output
        mock_ai_model_instance.generate_content.return_value = mock_ai_response

        with self.app.test_request_context('/'):
            response = assign_people_to_items(mock_request)

        self.assertEqual(response.status_code, 400) # Expect 400 if main.py handles Pydantic's ValueError
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        # The exact message depends on how main.py formats Pydantic validation errors
        self.assertIn("Output validation failed", response_data.get("error", {}).get("message", str(response_data.get("error"))))

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'})
    @patch('main.genai_legacy.GenerativeModel')  # Fix: patch the alias used in main.py
    @patch('main.get_dynamic_config')
    def test_assign_people_to_items_ai_service_error(self, mock_get_dynamic_config, 
                                                  mock_genai_model_constructor):
        mock_get_dynamic_config.return_value = self.valid_assign_config_dict

        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        input_data = {
            "parsed_receipt_items": [{"name": "Drink", "quantity": 1, "price": 3.00}],
            "people_names": ["Charlie"],
            "user_prompt_customizations": "Charlie had the drink."
        }
        mock_request.get_json.return_value = {"data": input_data}

        # Create mock generative model with error
        mock_ai_model_instance = mock_genai_model_constructor.return_value
        ai_error_message = "Simulated AI Service Error for assignments"
        mock_ai_model_instance.generate_content.side_effect = Exception(ai_error_message)

        with self.app.test_request_context('/'):
            response = assign_people_to_items(mock_request)

        self.assertEqual(response.status_code, 500)
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        self.assertIn(ai_error_message, response_data.get("error", {}).get("message", str(response_data.get("error"))))

    # Add missing test for input validation mentioned in test_coverage.md
    @patch('main.get_dynamic_config')
    def test_assign_people_input_validation(self, mock_get_dynamic_config):
        mock_get_dynamic_config.return_value = self.valid_assign_config_dict
        
        # Test case 1: missing parsed_receipt_items
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        # Missing parsed_receipt_items
        input_data = {
            "people_names": ["David"],
            "user_prompt_customizations": "David had something."
        }
        mock_request.get_json.return_value = {"data": input_data}
        
        with self.app.test_request_context('/'):
            response = assign_people_to_items(mock_request)
            
        self.assertEqual(response.status_code, 400)
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        # Check for appropriate error message based on implementation
        
        # Test case 2: missing people_names
        mock_request = MagicMock(spec=https_fn.Request)
        mock_request.method = "POST"
        # Missing people_names
        input_data = {
            "parsed_receipt_items": [{"name": "Salad", "quantity": 1, "price": 5.00}],
            "user_prompt_customizations": "Someone had the salad."
        }
        mock_request.get_json.return_value = {"data": input_data}
        
        with self.app.test_request_context('/'):
            response = assign_people_to_items(mock_request)
            
        self.assertEqual(response.status_code, 400)
        response_data = json.loads(response.get_data(as_text=True))
        self.assertIn("error", response_data)
        # Check for appropriate error message based on implementation

if __name__ == '__main__':
    unittest.main() 
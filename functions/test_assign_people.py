import unittest
from unittest.mock import patch, MagicMock
import os
# import tempfile # Not obviously used by this test class
from flask import Flask
from firebase_functions import https_fn # For mocking Request and Response objects
import json # For checking the JSON response

from main import assign_people_to_items, AssignPeopleToItems, PersonItemAssignment, ItemDetail, SharedItemDetail # Import necessary items

class TestAssignPeopleToItems(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        self.google_api_key = "mock_google_api_key_value"
        self.openai_api_key = "mock_openai_api_key_value"

    def _get_valid_assign_config(self):
        mock_config_instance = MagicMock()
        config_values = {
            'provider_name': 'gemini',
            'model_name': 'gemini-1.0-pro', # As per original test
            'api_key_secret': 'GOOGLE_API_KEY',
            'prompt_template': 'Assign people to items. Parsed: {parsed_receipt_json}, People: {people_list_str}, User prompt: {user_customizations}'
        }
        mock_config_instance.get.side_effect = lambda key: config_values.get(key)
        return mock_config_instance

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.generativeai.GenerativeModel') # CORRECTED PATH
    def test_assign_people_to_items_success(self, mock_genai_model_class, mock_get_config):
        # --- Setup Mocks ---
        mock_get_config.return_value = self._get_valid_assign_config() # USE HELPER
        config_values = self._get_valid_assign_config().get # For assertions
        
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
        mock_genai_model_class.assert_called_once_with(config_values('model_name'))
        
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
        self.assertIn(config_values('prompt_template').split('{parsed_receipt_json}')[0], actual_prompt) # Check static part

        self.assertEqual(response.status_code, 200)
        response_data_dict = json.loads(response.get_data(as_text=True))['data']
        self.assertEqual(response_data_dict, expected_assignment_data.model_dump())

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.generativeai.GenerativeModel') # CORRECTED PATH
    def test_assign_people_to_items_pydantic_validation_error(self, mock_genai_model_class, mock_get_config):
        # --- Setup Mocks ---
        mock_get_config.return_value = self._get_valid_assign_config() # USE HELPER
        
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
        self.assertIn("Output validation failed", response_data.get("error", {}).get("message", str(response_data.get("error"))))

    @patch.dict(os.environ, {'GOOGLE_API_KEY': 'fake_test_api_key'}) # Add API key to environment
    @patch('main.get_dynamic_config')
    @patch('google.generativeai.GenerativeModel') # CORRECTED PATH
    def test_assign_people_to_items_ai_service_error(self, mock_genai_model_class, mock_get_config):
        # --- Setup Mocks ---
        mock_get_config.return_value = self._get_valid_assign_config() # USE HELPER

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
        self.assertIn(ai_error_message, response_data.get("error", {}).get("message", str(response_data.get("error"))))

if __name__ == '__main__':
    unittest.main() 
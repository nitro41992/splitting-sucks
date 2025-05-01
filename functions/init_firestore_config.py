#!/usr/bin/env python
"""
Initialize Firestore configurations for dynamic prompts and models.
This script populates the Firestore database with default configurations,
supporting multiple AI providers for both prompts and models.
"""

import firebase_admin
from firebase_admin import credentials, firestore
import datetime
import argparse
import os

# Default configurations structure with provider support for prompts and models
DEFAULT_CONFIGS = {
    "parse_receipt": {
        "prompts": { # Changed from "prompt" to "prompts" map
            "openai": {"prompt_text": """Parse the image and generate a JSON representing the receipt.

**Instructions:**
- Sometimes, items may have add-ons or modifiers in the receipt. Use your intuition to roll up the add-ons into the parent item and sum the prices.
- MAKE SURE the price is the individual price for the item and the quantity is accurate based on the receipt. (e.g., If the receipt says Quantity of 2 and price is $10, then the price of the item to provide is $5, not $10)
- MAKE SURE all items, quantities, and prices are present and accurate in the json.
- First, accurately transcribe every item and its listed price exactly as shown on the receipt, before performing any calculations or transformations. Only after verifying transcription, adjust for quantities.
- If an item or line has its own price listed to the far right of it, it must be treated as a separate line item in the JSON, even if it appears visually indented, grouped, or described as part of a larger item. Do not assume bundling unless there is no separate price.

You should return ONLY a JSON object (no extra text or explanation) that contains the following keys:
- items: A list of dictionaries representing individual items. Each dictionary should have the following keys:
    - item: The name of the item.
    - quantity: The quantity of the item.
    - price: The price of one unit of the item.
- subtotal: The subtotal amount."""},
            "gemini": {"prompt_text": """Analyze the provided receipt image.

**Task:** Extract information and return ONLY a valid JSON object adhering to the specified schema. Do not include markdown formatting (like ```json) or any surrounding text.

**JSON Schema:**
{
  "items": [
    {
      "item": "<item_name>",
      "quantity": <integer_quantity>,
      "price": <float_unit_price>
    }
    ...
  ],
  "subtotal": <float_subtotal_amount>
}

**Extraction Rules:**
1.  **Add-ons/Modifiers:** Roll up add-ons/modifiers into the parent item, summing their prices into the parent item's price.
2.  **Quantity/Price Adjustment:** Ensure the 'price' in the JSON is the *unit price*. If the receipt shows Quantity: 2, Price: $10.00, the JSON should have quantity: 2, price: 5.00.
3.  **Completeness:** Include ALL items listed on the receipt in the 'items' array.
4.  **Accuracy:** Ensure item names, quantities, and calculated unit prices are accurate.
5.  **Transcription First:** Mentally transcribe items/prices exactly first, then apply adjustments for quantity.
6.  **Separate Lines:** Treat any line with its own distinct price as a separate item in the JSON, even if visually grouped.

Return *only* the JSON object."""}
        },
        "model_config": { # Nest model config under its own key for clarity
            "default_selected_provider": "openai",
            "providers": {
                "openai": {
                    "model_name": "gpt-4o",
                    "max_tokens": 4096
                },
                "gemini": {
                    "model_name": "gemini-1.5-flash",
                    "max_tokens": 8192
                }
            }
        }
    },
    "assign_people_to_items": {
        "prompts": {
            "openai": {"prompt_text": """You are a helpful assistant that assigns items from a receipt to people based on voice instructions.
Analyze the voice transcription and the provided JSON list of receipt items to determine who ordered what. Each item in the receipt list has a numeric 'id'.

**Instructions:**
1.  Analyze the voice transcription carefully.
2.  Use the provided item 'id's when assigning items.
3.  Include ALL people mentioned in the transcription in the output.
4.  Assign every item from the receipt list to a person, mark it as 'shared', or add it to 'unassigned_items'.
5.  Ensure quantities in the assignments match the receipt (provide positive integers).
6.  If not all instances of an item are assigned via transcription, place the remaining quantity/item in 'unassigned_items'.
7.  Pay close attention if the transcription uses numbers that seem to correspond to item 'id's.

Return ONLY a JSON object matching the following structure:
{
  "assignments": {
    "<person_name>": [
      {"id": <item_id>, "quantity": <int>}
    ],
    ...
  },
  "shared_items": [
    {"id": <item_id>, "quantity": <int>}
  ],
  "unassigned_items": [
    {"id": <item_id>, "quantity": <int>}
  ]
}
"""},
            "gemini": {"prompt_text": """**Task:** Assign items from a receipt (provided as a JSON list) to people based on a voice transcription.

**Input:**
1.  Voice Transcription (string)
2.  Receipt Items (JSON list, each item has an integer 'id', 'item', 'quantity', 'price')

**Output:** Return ONLY a valid JSON object (no extra text or markdown) with the following structure:
{
  "assignments": {
    "<person_name>": [
      {"id": <item_id>, "quantity": <integer_assignment_quantity>}
    ],
    ...
  },
  "shared_items": [
    {"id": <item_id>, "quantity": <integer_shared_quantity>}
  ],
  "unassigned_items": [
    {"id": <item_id>, "quantity": <integer_unassigned_quantity>}
  ]
}

**Assignment Rules:**
1.  Carefully parse the transcription to identify people and the items (referencing by 'id') they claim.
2.  Include ALL people mentioned in the output JSON's "assignments" section (even if they claim nothing).
3.  Every item from the input receipt list must be accounted for. Assign it to a person, list it under "shared_items", or list it under "unassigned_items".
4.  The sum of quantities for a specific item ID across "assignments", "shared_items", and "unassigned_items" must equal the original quantity of that item in the input receipt list.
5.  If the transcription mentions item numbers, assume they correspond to the item 'id's.
6.  If an item is mentioned but not all quantity is claimed, assign the claimed amount and put the remainder in "unassigned_items".

Return *only* the JSON object."""}
        },
        "model_config": {
            "default_selected_provider": "openai",
            "providers": {
                "openai": {
                    "model_name": "gpt-4o",
                    "max_tokens": 4096
                },
                "gemini": {
                    "model_name": "gemini-1.5-flash",
                    "max_tokens": 8192
                }
            }
        }
    },
    "transcribe_audio": {
        "prompts": { # Prompts usually not applicable for dedicated transcription APIs
            "openai": {"prompt_text": None},
            "gemini": {"prompt_text": None} # Gemini models might accept prompts for transcription context, TBD
        },
        "model_config": {
            "default_selected_provider": "openai",
            "providers": {
                "openai": {
                    "model_name": "whisper-1",
                    "max_tokens": None
                },
                "gemini": {
                    "model_name": "gemini-1.5-flash",
                    "max_tokens": None
                }
            }
        }
    }
}

def initialize_firestore_config(cred_path=None, admin_uid="admin"):
    """Initialize Firestore with default configurations supporting multiple providers for prompts and models.

    Args:
        cred_path (str): Path to the Firebase credentials JSON file
        admin_uid (str): Admin user ID to associate with the configurations
    """
    # Check if Firebase already initialized
    try:
        app = firebase_admin.get_app()
    except ValueError:
        # Initialize Firebase Admin SDK with credentials
        if cred_path and os.path.exists(cred_path):
            print(f"Initializing Firebase with credentials from: {cred_path}")
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
        else:
            print("No credentials provided or file not found. Trying default initialization (uses GOOGLE_APPLICATION_CREDENTIALS)...")
            # This will use GOOGLE_APPLICATION_CREDENTIALS env var or default app
            firebase_admin.initialize_app()

    # Get Firestore client
    db = firestore.client()
    timestamp = datetime.datetime.now(datetime.timezone.utc) # Use timezone-aware timestamp

    # Initialize configurations for each service
    for service_name, service_data in DEFAULT_CONFIGS.items(): # Iterate through service data
        try:
            # Create/Update prompt document with providers map
            prompt_ref = db.collection("configs").document("prompts").collection(service_name).document("current")
            prompt_config_data = {
                "providers": service_data["prompts"], # Store the whole prompts map
                "version": 1,
                "last_updated": timestamp,
                "created_by": admin_uid
            }
            prompt_ref.set(prompt_config_data) # Removed merge=True to ensure overwrite
            print(f"Set prompt configuration for {service_name}")

            # Create/Update model document with new structure
            model_ref = db.collection("configs").document("models").collection(service_name).document("current")
            # Extract model config part from service_data
            model_config = service_data["model_config"]
            model_firestore_data = {
                "selected_provider": model_config["default_selected_provider"],
                "providers": model_config["providers"],
                "version": 1,
                "last_updated": timestamp,
                "created_by": admin_uid
            }

            model_ref.set(model_firestore_data) # Removed merge=True to ensure overwrite
            print(f"Set model configuration for {service_name}")

        except Exception as e:
            print(f"!!! ERROR setting configuration for {service_name}: {e}") # Added error printing

    print("\nFirestore configuration initialization/update complete!")
    print("You can now manage provider-specific prompts and models in Firestore.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Initialize Firestore with default configurations for dynamic prompts and models (multi-provider).")
    parser.add_argument("--admin-uid", default="admin_script", help="Admin user ID to associate with the configurations") # Changed default
    parser.add_argument("--cred-path", help="Path to the Firebase service account credentials JSON file (optional, uses GOOGLE_APPLICATION_CREDENTIALS otherwise)")
    args = parser.parse_args()

    initialize_firestore_config(cred_path=args.cred_path, admin_uid=args.admin_uid) 
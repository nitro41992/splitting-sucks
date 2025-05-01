#!/usr/bin/env python
"""
Initialize Firestore configurations for dynamic prompts.
This script populates the Firestore database with default configurations for AI prompts and models.
"""

import firebase_admin
from firebase_admin import credentials, firestore
import datetime
import argparse
import os

# Default configurations
DEFAULT_CONFIGS = {
    "parse_receipt": {
        "prompt": '''Parse the image and generate a receipts.

**Instructions:**
- Sometimes, items may have add-ons or modifiers in the receipt. 
    - Use your intution to roll up the add-ons into the parent item and sum the prices.
- MAKE SURE the price is the individiual price for the item and the quantity is accurate based on the receipt. (ex. If the receipt says Quantity of 2 and price is $10, then the price of the item to provide is $5, not $10)
- MAKE SURE all items, quantities, and prices are present and accurate in the json

You should return a JSON object that contains the following keys:
- items: A list of dictionaries representing individual items. Each dictionary should have the following keys:
    - item: The name of the item.
    - quantity: The quantity of the item.
    - price: The price of one unit of the item.
- subtotal: The subtotal amount.

Instructions:
- First, accurately transcribe every item and its listed price exactly as shown on the receipt, before performing any calculations or transformations. Do not assume or infer numbers — copy the listed amount first. Only after verifying transcription, adjust for quantities.
- Sometimes, items may have add-ons or modifiers in the receipt.
- Use your intuition to roll up the add-ons into the parent item and sum the prices.
- If an item or line has its own price listed to the far right of it, it must be treated as a separate line item in the JSON, even if it appears visually indented, grouped, or described as part of a larger item. Do not assume bundling unless there is no separate price.
- MAKE SURE the price is the individual price for the item and the quantity is accurate based on the receipt. (ex. If the receipt says Quantity of 2 and price is $10, then the price of the item to provide is $5, not $10)
- MAKE SURE all items, quantities, and prices are present and accurate in the json''',
        "model": "gpt-4.1",
        "max_tokens": 32768
    },
    "assign_people_to_items": {
        "prompt": '''You are a helpful assistant that assigns items from a receipt to people based on voice instructions.
Analyze the voice transcription and receipt items to determine who ordered what.
Each item in the receipt items list has a numeric 'id'. Use these IDs to refer to items when possible, especially if the transcription mentions numbers.

Pay close attention to:
1. Include ALL people mentioned in the transcription
2. Make sure all items are assigned to someone, marked as shared, or added to the unassigned_items array. Its important to include all items.
3. Ensure quantities and prices match the receipt, providing a positive integer for quantity.
4. If not every instance of an item is mentioned in the transcription, make sure to add the item to the unassigned_items array
5. If numeric references to items are provided, use the provided numeric IDs to reference items when the transcription includes numbers that seem to correspond to items.''',
        "model": "gpt-4.1",
        "max_tokens": 32768
    },
    "transcribe_audio": {
        "prompt": None,  # Whisper API doesn't use a prompt
        "model": "whisper-1",
        "max_tokens": None  # Not applicable for Whisper
    }
}

def initialize_firestore_config(cred_path=None, admin_uid="admin"):
    """Initialize Firestore with default configurations.
    
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
            print("No credentials provided or file not found. Trying default initialization...")
            # This will use GOOGLE_APPLICATION_CREDENTIALS env var or default app
            firebase_admin.initialize_app()
    
    # Get Firestore client
    db = firestore.client()
    timestamp = datetime.datetime.now()
    
    # Initialize configurations for each service
    for service_name, config in DEFAULT_CONFIGS.items():
        # Create prompt document
        if config["prompt"] is not None:
            prompt_ref = db.collection("configs").document("prompts").collection(service_name).document("current")
            prompt_ref.set({
                "prompt_text": config["prompt"],
                "version": 1,
                "last_updated": timestamp,
                "created_by": admin_uid
            })
            print(f"Created prompt configuration for {service_name}")
        
        # Create model document
        model_ref = db.collection("configs").document("models").collection(service_name).document("current")
        model_data = {
            "model_name": config["model"],
            "version": 1,
            "last_updated": timestamp,
            "created_by": admin_uid
        }
        if config["max_tokens"] is not None:
            model_data["max_tokens"] = config["max_tokens"]
        
        model_ref.set(model_data)
        print(f"Created model configuration for {service_name}")
    
    print("\nFirestore configuration initialization complete!")
    print("You can now edit the prompts and model configurations directly in Firestore.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Initialize Firestore with default configurations for dynamic prompts")
    parser.add_argument("--admin-uid", default="admin", help="Admin user ID to associate with the configurations")
    parser.add_argument("--cred-path", help="Path to the Firebase service account credentials JSON file")
    args = parser.parse_args()
    
    initialize_firestore_config(cred_path=args.cred_path, admin_uid=args.admin_uid) 
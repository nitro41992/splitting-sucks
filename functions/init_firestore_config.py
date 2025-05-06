#!/usr/bin/env python
"""
Initialize Firestore configurations for dynamic prompts and models.
This script loads configurations from emulator_seed_data directory
and populates the Firestore database with these configurations.
"""

import firebase_admin
from firebase_admin import credentials, firestore
import datetime
import argparse
import os
import json
import glob

def load_models_and_prompts_from_seed_data(seed_data_dir):
    """
    Load model and prompt configurations from emulator seed data files.
    
    Args:
        seed_data_dir (str): Path to the emulator_seed_data directory
        
    Returns:
        dict: Dictionary of configurations by service name
    """
    configs = {}
    base_path = os.path.join(seed_data_dir, "firestore_export", "configs")
    
    if not os.path.exists(base_path):
        print(f"Error: Config path not found: {base_path}")
        return {}
    
    # Find all service directories
    model_dirs = glob.glob(os.path.join(base_path, "models", "*"))
    if not model_dirs:
        print(f"Warning: No model directories found in {os.path.join(base_path, 'models')}")
        return {}
        
    service_names = [os.path.basename(d) for d in model_dirs]
    print(f"Found service directories: {', '.join(service_names)}")
    
    for service_name in service_names:
        configs[service_name] = {"model_config": {}, "prompts": {}}
        
        # Load model configuration
        model_path = os.path.join(base_path, "models", service_name, "current.json")
        if os.path.exists(model_path):
            try:
                with open(model_path, 'r', encoding='utf-8') as f:
                    model_data = json.load(f)
                    configs[service_name]["model_config"] = {
                        "default_selected_provider": model_data.get("selected_provider", "openai"),
                        "providers": model_data.get("providers", {})
                    }
                    print(f"Loaded model configuration for {service_name}")
            except Exception as e:
                print(f"Error loading model configuration for {service_name}: {e}")
        else:
            print(f"Warning: No current.json found for {service_name} model at {model_path}")
        
        # Load prompt configuration
        prompt_path = os.path.join(base_path, "prompts", service_name, "current.json")
        if os.path.exists(prompt_path):
            try:
                with open(prompt_path, 'r', encoding='utf-8') as f:
                    prompt_data = json.load(f)
                    configs[service_name]["prompts"] = prompt_data.get("providers", {})
                    print(f"Loaded prompt configuration for {service_name}")
            except Exception as e:
                print(f"Error loading prompt configuration for {service_name}: {e}")
        else:
            print(f"Warning: No current.json found for {service_name} prompt at {prompt_path}")
    
    # Only keep services with valid configurations
    valid_configs = {k: v for k, v in configs.items() if v["model_config"] or v["prompts"]}
    if not valid_configs:
        print("No valid configurations found in seed data directory.")
    else:
        print(f"Found valid configurations for: {', '.join(valid_configs.keys())}")
    
    return valid_configs

def initialize_firestore_config(cred_path=None, admin_uid="admin", seed_data_dir="emulator_seed_data"):
    """Initialize Firestore with configurations from seed data directory.

    Args:
        cred_path (str): Path to the Firebase credentials JSON file
        admin_uid (str): Admin user ID to associate with the configurations
        seed_data_dir (str): Path to the emulator_seed_data directory
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
    timestamp = datetime.datetime.now(datetime.timezone.utc)

    # Load configurations from seed data
    configs = load_models_and_prompts_from_seed_data(seed_data_dir)
    if not configs:
        print("No configurations found in seed data directory. Exiting.")
        return

    # Initialize configurations for each service
    for service_name, service_data in configs.items():
        try:
            # Create/Update prompt document with providers map
            if service_data["prompts"]:
                prompt_ref = db.collection("configs").document("prompts").collection(service_name).document("current")
                prompt_config_data = {
                    "providers": service_data["prompts"],
                    "version": 1,
                    "last_updated": timestamp,
                    "created_by": admin_uid
                }
                prompt_ref.set(prompt_config_data)
                print(f"Set prompt configuration for {service_name}")

            # Create/Update model document
            if service_data["model_config"]:
                model_ref = db.collection("configs").document("models").collection(service_name).document("current")
                model_config = service_data["model_config"]
                model_firestore_data = {
                    "selected_provider": model_config["default_selected_provider"],
                    "providers": model_config["providers"],
                    "version": 1,
                    "last_updated": timestamp,
                    "created_by": admin_uid
                }

                model_ref.set(model_firestore_data)
                print(f"Set model configuration for {service_name}")

        except Exception as e:
            print(f"!!! ERROR setting configuration for {service_name}: {e}")

    print("\nFirestore configuration initialization/update complete!")
    print("You can now manage provider-specific prompts and models in Firestore.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Initialize Firestore with configurations from emulator seed data.")
    parser.add_argument("--admin-uid", default="admin", help="Admin user ID to associate with the configurations")
    parser.add_argument("--cred-path", help="Path to the Firebase service account credentials JSON file")
    parser.add_argument("--seed-data-dir", default="emulator_seed_data", help="Path to the emulator_seed_data directory")
    args = parser.parse_args()

    initialize_firestore_config(cred_path=args.cred_path, admin_uid=args.admin_uid, seed_data_dir=args.seed_data_dir) 
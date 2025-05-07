"""
Test script for Firebase Emulator Cloud Functions.

Edit the GCS URIs and project ID as needed before running.

Usage:
  python functions/test_emulator_functions.py

Requirements:
  pip install requests
"""
import requests
import json

# --- CONFIG ---
PROJECT_ID = "billfie"  # <-- Change to your Firebase project ID if different
EMULATOR_HOST = "http://127.0.0.1:5001"

# Provide your test GCS URIs here
IMAGE_GCS_URI = "gs://billfie.firebasestorage.app/PXL_20250419_011719007 (1).jpg"  # <-- Replace with your uploaded image URI
AUDIO_GCS_URI = "gs://billfie.firebasestorage.app/audio_28c3a3a2-009d-48cc-bc95-6c5918c3af62.wav"  # <-- Replace with your uploaded audio URI

# --- ENDPOINTS ---
PARSE_RECEIPT_URL = f"{EMULATOR_HOST}/{PROJECT_ID}/us-central1/parse_receipt"
TRANSCRIBE_AUDIO_URL = f"{EMULATOR_HOST}/{PROJECT_ID}/us-central1/transcribe_audio"
ASSIGN_PEOPLE_URL = f"{EMULATOR_HOST}/{PROJECT_ID}/us-central1/assign_people_to_items"


def pretty_print(title, data):
    print(f"\n=== {title} ===")
    print(json.dumps(data, indent=2))


def test_parse_receipt():
    payload = {"data": {"imageUri": IMAGE_GCS_URI}}
    resp = requests.post(PARSE_RECEIPT_URL, json=payload)
    try:
        resp_json = resp.json()
    except Exception:
        resp_json = resp.text
    pretty_print("parse_receipt response", resp_json)
    return resp_json


def test_transcribe_audio():
    payload = {"data": {"audioUri": AUDIO_GCS_URI}}
    resp = requests.post(TRANSCRIBE_AUDIO_URL, json=payload)
    try:
        resp_json = resp.json()
    except Exception:
        resp_json = resp.text
    pretty_print("transcribe_audio response", resp_json)
    return resp_json


def test_assign_people_to_items(receipt_items, transcription):
    # Format receipt items to match the expected structure
    formatted_items = []
    for idx, item in enumerate(receipt_items):
        formatted_items.append({
            "id": idx + 1,
            "name": item.get("item", item.get("name", "Item")),
            "quantity": item.get("quantity", 1),
            "price": item.get("price", 0.0)
        })
    
    # Simple payload with receipt items and transcription
    payload = {
        "data": {
            "receipt_items": formatted_items,
            "transcription": transcription
        }
    }
    
    print("Sending payload to assign_people_to_items:")
    pretty_print("Request payload", payload)
    
    resp = requests.post(ASSIGN_PEOPLE_URL, json=payload)
    try:
        resp_json = resp.json()
    except Exception:
        resp_json = resp.text
    pretty_print("assign_people_to_items response", resp_json)
    return resp_json


def main():
    print("Testing parse_receipt...")
    parse_result = test_parse_receipt()
    
    # Extract items from parse_receipt result
    items = []
    if isinstance(parse_result, dict):
        if "data" in parse_result and "items" in parse_result["data"]:
            items = parse_result["data"]["items"]
        elif "items" in parse_result:
            items = parse_result["items"]
    
    if not items:
        print("No items found in parse_receipt output. Skipping assign_people_to_items test.")
        return

    print("Testing transcribe_audio...")
    transcribe_result = test_transcribe_audio()
    
    # Extract transcription text
    transcription = ""
    if isinstance(transcribe_result, dict):
        if "data" in transcribe_result and "text" in transcribe_result["data"]:
            transcription = transcribe_result["data"]["text"]
        elif "text" in transcribe_result:
            transcription = transcribe_result["text"]
    
    if not transcription:
        print("No transcription found in transcribe_audio output. Using a placeholder.")
        transcription = "John gets 1 burger, Jane gets fries"

    print("Testing assign_people_to_items...")
    test_assign_people_to_items(items, transcription)


if __name__ == "__main__":
    main() 
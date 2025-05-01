# splitting_sucks

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Dynamic AI Prompts

The app uses a dynamic prompt system for AI interactions, allowing the modification of prompts and model configurations without redeploying Cloud Functions.

### Setup

1. Deploy the Cloud Functions with the dynamic configuration support
2. Run the initialization script to populate Firestore with default configurations:

```bash
cd functions
python init_firestore_config.py
```

### Usage

You can update AI prompts directly in the Firestore database:

1. Navigate to your Firebase project console
2. Go to Firestore Database
3. Edit the documents in `configs/prompts/[service_name]/current`

For detailed instructions, see [Firestore Configuration Setup](requirements/firestore_config_setup.md)

### Services

The following services support dynamic prompts:

1. **Parse Receipt** - Parses receipt images using OpenAI's vision capabilities
2. **Assign People to Items** - Assigns people to receipt items based on voice transcription
3. **Transcribe Audio** - Transcribes audio using OpenAI's Whisper API

### Security

Only authenticated admin users can modify the prompts and model configurations in Firestore. The Cloud Functions service account has read-only access to the configurations.

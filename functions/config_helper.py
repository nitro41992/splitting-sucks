from firebase_admin import firestore
import logging

# Default configurations (can be used as fallback if Firestore fetch fails)
# Updated to reflect provider-specific prompts
DEFAULT_FALLBACKS = {
    "parse_receipt": {
        "provider_name": "openai",
        "model": "gpt-4o",
        "max_tokens": 4096,
        "prompt": "Default OpenAI prompt for parsing receipt..." # Default prompt is now provider-specific
    },
    "assign_people_to_items": {
        "provider_name": "openai",
        "model": "gpt-4o",
        "max_tokens": 4096,
        "prompt": "Default OpenAI prompt for assigning items..."
    },
    "transcribe_audio": {
        "provider_name": "openai",
        "model": "whisper-1",
        "max_tokens": None,
        "prompt": None
    }
    # Note: We might need Gemini-specific fallbacks if the default provider changes
}


def get_dynamic_config(service_name):
    """Fetch dynamic configuration including selected provider and its specific details (model and prompt).

    Fetches model and prompt configurations, determines the selected provider from the model config,
    and retrieves the corresponding model details and prompt text.

    Args:
        service_name (str): The name of the service ('parse_receipt', 'assign_people_to_items', 'transcribe_audio').

    Returns:
        dict: Configuration containing 'prompt', 'provider_name', 'model', 'max_tokens'.
              Returns fallback defaults if Firestore fetch fails or data is incomplete.
    """
    # Start with defaults for the default provider (usually OpenAI)
    default_provider = DEFAULT_FALLBACKS.get(service_name, {}).get("provider_name", "openai")
    config = DEFAULT_FALLBACKS.get(service_name, {}).copy()

    selected_provider = default_provider # Assume default provider initially
    prompt_text = config.get('prompt') # Start with default prompt

    try:
        db = firestore.client()

        # 1. Fetch model configuration to determine the selected provider
        model_ref = db.collection('configs').document('models').collection(service_name).document('current')
        model_doc = model_ref.get()

        if model_doc.exists:
            model_data = model_doc.to_dict()
            provider_from_model_config = model_data.get('selected_provider')
            providers_map = model_data.get('providers', {})

            if provider_from_model_config and provider_from_model_config in providers_map:
                selected_provider = provider_from_model_config # Update selected provider
                provider_config = providers_map[selected_provider]
                config['provider_name'] = selected_provider
                config['model'] = provider_config.get('model_name')
                config['max_tokens'] = provider_config.get('max_tokens')
            else:
                logging.warning(f"Selected provider '{provider_from_model_config}' not found or invalid in model config for {service_name}, using default provider '{selected_provider}'.")
                # Keep default model details if selected provider is invalid
                config['provider_name'] = selected_provider
                config['model'] = DEFAULT_FALLBACKS.get(service_name, {}).get('model')
                config['max_tokens'] = DEFAULT_FALLBACKS.get(service_name, {}).get('max_tokens')
        else:
            logging.warning(f"Model configuration document not found for {service_name}, using default provider '{selected_provider}'.")
            # Keep default model details
            config['provider_name'] = selected_provider
            config['model'] = DEFAULT_FALLBACKS.get(service_name, {}).get('model')
            config['max_tokens'] = DEFAULT_FALLBACKS.get(service_name, {}).get('max_tokens')

        # 2. Fetch prompt configuration using the determined selected_provider
        prompt_ref = db.collection('configs').document('prompts').collection(service_name).document('current')
        prompt_doc = prompt_ref.get()
        prompt_found_for_provider = False
        if prompt_doc.exists:
            prompt_data = prompt_doc.to_dict()
            prompt_providers_map = prompt_data.get('providers', {})
            if selected_provider in prompt_providers_map:
                provider_prompt_config = prompt_providers_map[selected_provider]
                fetched_prompt = provider_prompt_config.get('prompt_text')
                # Use fetched prompt only if it's not None/empty
                if fetched_prompt:
                    prompt_text = fetched_prompt
                    prompt_found_for_provider = True

        if not prompt_found_for_provider:
             logging.warning(f"Prompt text not found for provider '{selected_provider}' for service {service_name}. Using default prompt.")
             # Ensure we fall back to the correct default prompt if Firestore lookup failed
             prompt_text = DEFAULT_FALLBACKS.get(service_name, {}).get('prompt')

        config['prompt'] = prompt_text

        # Clean up None prompt for services like transcribe_audio if necessary
        if config['prompt'] is None and service_name == 'transcribe_audio':
             pass # Allow None prompt for transcription
        elif config['prompt'] is None:
             logging.warning(f"Final prompt is None for service {service_name}, which might be unexpected.")
             # Fallback to a generic default if absolutely needed, though DEFAULT_FALLBACKS should handle this
             config['prompt'] = "Default fallback prompt."


        logging.info(f"Retrieved dynamic config for {service_name}: provider='{config.get('provider_name')}', model='{config.get('model')}'")
        return config

    except Exception as e:
        logging.error(f"Error fetching dynamic configuration for {service_name}: {e}. Returning defaults.")
        # Return a copy of the defaults for the specific service in case of error
        return DEFAULT_FALLBACKS.get(service_name, {}).copy() 
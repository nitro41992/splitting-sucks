from firebase_admin import firestore
import logging

def get_dynamic_config(service_name):
    """Fetch dynamic configuration with fallbacks.
    
    Args:
        service_name (str): The name of the service ('parse_receipt', 'assign_people_to_items', 'transcribe_audio')
        
    Returns:
        dict: Configuration with prompt, model, and max_tokens or None if fetch fails
    """
    try:
        db = firestore.client()
        
        # Fetch prompt configuration
        prompt_ref = db.collection('configs').document('prompts').collection(service_name).document('current')
        prompt_data = prompt_ref.get()
        
        # Fetch model configuration
        model_ref = db.collection('configs').document('models').collection(service_name).document('current')
        model_data = model_ref.get()
        
        # Create configuration dict and track source of values
        config = {
            'prompt': prompt_data.to_dict().get('prompt_text') if prompt_data.exists else None,
            'model': model_data.to_dict().get('model_name') if model_data.exists else None,
            'max_tokens': model_data.to_dict().get('max_tokens') if model_data.exists else None,
            'sources': {
                'prompt': 'firestore' if prompt_data.exists and prompt_data.to_dict().get('prompt_text') else 'default',
                'model': 'firestore' if model_data.exists and model_data.to_dict().get('model_name') else 'default',
                'max_tokens': 'firestore' if model_data.exists and model_data.to_dict().get('max_tokens') else 'default'
            }
        }
        
        logging.info(f"Retrieved dynamic config for {service_name}: {config}")
        return config
    except Exception as e:
        logging.error(f"Error fetching dynamic configuration for {service_name}: {e}")
        return None 
# assistant/chatbot.py (Full Version)
import os
import google.generativeai as genai

chat_session = None

def configure_ai():
    """Initializes the AI model using the API key from the environment."""
    global chat_session
    try:
        api_key = os.getenv("GOOGLE_API_KEY")
        if not api_key:
            print("Error: GOOGLE_API_KEY environment variable not set.")
            return

        genai.configure(api_key=api_key)
        model = genai.GenerativeModel('gemini-1.5-flash')
        chat_session = model.start_chat(history=[])
        print("AI model configured successfully.")
    except Exception as e:
        print(f"Error configuring Google AI: {e}")
        chat_session = None

def get_chatbot_response(prompt: str) -> str:
    """Sends a prompt to the ongoing chat session and gets a response."""
    if not chat_session:
        return "AI model is not configured. Please check the server logs for an API key error."
    try:
        response = chat_session.send_message(prompt)
        return response.text
    except Exception as e:
        return f"An error occurred while getting a response: {str(e)}"

# --- NEW FUNCTION TO GENERATE FINAL FEEDBACK ---
def generate_feedback_from_history(history: str) -> str:
    """Sends a full conversation history to the AI and asks for feedback."""
    if not chat_session:
        return "AI model is not configured."

    # A special prompt that tells the AI what we want it to do
    feedback_prompt = (
        "You are an IELTS speaking examiner. Based on the following conversation transcript, "
        "provide overall feedback for the user, highlighting strengths and areas for improvement "
        "in fluency, vocabulary, grammar, and pronunciation. Keep the feedback concise and encouraging.\n\n"
        "--- CONVERSATION TRANSCRIPT ---\n"
        f"{history}\n"
        "--- END OF TRANSCRIPT ---\n\n"
        "FINAL FEEDBACK:"
    )
    
    try:
        # We use generate_content for a one-off request, not the ongoing chat session
        model = genai.GenerativeModel('gemini-1.5-flash')
        response = model.generate_content(feedback_prompt)
        return response.text
    except Exception as e:
        return f"An error occurred while generating feedback: {str(e)}"
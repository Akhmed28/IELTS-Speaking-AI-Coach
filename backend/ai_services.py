# ai_services.py (New "Deep Dive" Version)

import os
import google.generativeai as genai
from typing import Dict, List, Any
from dotenv import load_dotenv
import json
import re

load_dotenv()

try:
    genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))
    model = genai.GenerativeModel('gemini-1.5-flash')
except Exception as e:
    print(f"❌ AI Service Error: Failed to configure Google AI. Check API Key. Error: {e}")
    model = None

def clean_json_response(text: str) -> str:
    start = text.find('{')
    end = text.rfind('}')
    if start == -1 or end == -1: return "{}"
    json_str = text[start:end+1]
    json_str = re.sub(r',\s*([}\]])', r'\1', json_str)
    return json_str

async def get_ai_final_feedback(conversation: List[Dict[str, Any]]) -> Dict:
    if not model:
        # Return a structure that matches the new schema
        return { "overall_band_score": 0, "fluency_score": 0, "lexical_score": 0, "grammar_score": 0, "pronunciation_score": 0, "general_summary": "AI service is not configured.", "answer_analyses": [] }

    transcript = "\n".join([
        f"Examiner: {msg.get('question', 'N/A')}\nStudent: {msg.get('answer', 'N/A')}"
        for msg in conversation
    ])
    
    # --- The New, "Deep Dive" Prompt ---
    prompt = f"""
    You are an expert IELTS examiner providing a detailed, sentence-by-sentence analysis of a student's performance.
    Analyze the following transcript.

    --- TRANSCRIPT ---
    {transcript}
    --- END TRANSCRIPT ---

    Your task is to return ONLY a JSON object with the following structure. Do not include any text before or after the JSON.

    {{
      "overall_band_score": <float from 4.0-9.0>,
      "fluency_score": <integer from 4-9>,
      "lexical_score": <integer from 4-9>,
      "grammar_score": <integer from 4-9>,
      "pronunciation_score": <integer from 4-9>,
      "general_summary": "<A concise summary of the student's overall performance.>",
      "answer_analyses": [
        {{
          "question": "<The first examiner question>",
          "answer": "<The student's full answer to the first question>",
          "grammar_feedback": [
            {{
              "sentence": "<The specific sentence from the student's answer with a grammatical error>",
              "feedback": "<A brief explanation of the error (e.g., 'Incorrect verb tense')>",
              "suggestion": "<The corrected version of the sentence>"
            }}
          ],
          "vocabulary_feedback": [
            {{
              "sentence": "<The specific sentence where vocabulary could be improved>",
              "feedback": "<Explanation of why it could be improved (e.g., 'Repetitive word choice')>",
              "suggestion": "<The same sentence but with more advanced or appropriate vocabulary>"
            }}
          ],
          "fluency_feedback": "<A brief comment on the fluency and coherence of this specific answer>"
        }}
      ]
    }}

    VERY IMPORTANT INSTRUCTIONS:
    1.  Go through EACH question and answer pair and create one entry in the "answer_analyses" array for it.
    2.  For "grammar_feedback" and "vocabulary_feedback", if you find NO errors or areas for improvement for a specific answer, you MUST return an empty array: [].
    3.  DO NOT invent errors. If the grammar or vocabulary is perfect for an answer, the corresponding arrays should be empty.
    """

    try:
        response = await model.generate_content_async(prompt)
        cleaned_text = clean_json_response(response.text)
        feedback_data = json.loads(cleaned_text)
        return feedback_data
    except Exception as e:
        print(f"❌ AI Service Error: Could not parse deep feedback response. Error: {str(e)}")
        # Return a default error response that matches the new schema
        return { "overall_band_score": 0, "fluency_score": 0, "lexical_score": 0, "grammar_score": 0, "pronunciation_score": 0, "general_summary": "An error occurred generating feedback.", "answer_analyses": [] }
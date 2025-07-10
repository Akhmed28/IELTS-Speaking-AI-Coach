# azure_tts_service.py (Final Corrected Version)

import os
from dotenv import load_dotenv
import azure.cognitiveservices.speech as speechsdk
import asyncio # 👈 Make sure this import is added
import io

load_dotenv()

speech_key = os.getenv("AZURE_SPEECH_KEY")
speech_region = os.getenv("AZURE_SPEECH_REGION")

VOICE_PRESETS = {
    "female_us": "en-US-JennyNeural",
    "male_us": "en-US-GuyNeural",
    "female_uk": "en-GB-SoniaNeural",
    "male_uk": "en-GB-RyanNeural",
    "female_au": "en-AU-NatashaNeural",
}
DEFAULT_VOICE = "en-US-JennyNeural"

if not speech_key or not speech_region:
    print("⚠️ AZURE TTS WARNING: Azure Speech key or region not found in .env file.")
    speech_config = None
else:
    print("✅ AZURE TTS INFO: Azure credentials loaded successfully.")
    speech_config = speechsdk.SpeechConfig(subscription=speech_key, region=speech_region)
    speech_config.set_speech_synthesis_output_format(speechsdk.SpeechSynthesisOutputFormat.Audio16Khz64KBitRateMonoMp3)


async def text_to_speech_async(text: str, voice_id: str | None = None) -> bytes | None:
    if not speech_config:
        print("❌ AZURE TTS ERROR: speech_config is not available. Check .env file.")
        return None
    if not text.strip():
        print("❌ AZURE TTS ERROR: Input text is empty.")
        return None

    voice_name = VOICE_PRESETS.get(voice_id, DEFAULT_VOICE) if voice_id else DEFAULT_VOICE
    speech_config.speech_synthesis_voice_name = voice_name
    
    synthesizer = speechsdk.SpeechSynthesizer(speech_config=speech_config, audio_config=None)
    
    print(f"🎤 AZURE TTS INFO: Synthesizing speech with voice: {voice_name}")
    
    # --- THIS IS THE CORRECT AND FINAL FIX ---
    # The SDK's '.get()' method is a blocking call. We must run it in a 
    # separate thread to avoid freezing the server. `asyncio.to_thread`
    # is the standard and correct way to do this in an async application.
    future = synthesizer.speak_text_async(text)
    result = await asyncio.to_thread(future.get)
    
    if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
        print(f"✅ AZURE TTS SUCCESS: Synthesis successful, returning {len(result.audio_data)} bytes.")
        return result.audio_data
    elif result.reason == speechsdk.ResultReason.Canceled:
        cancellation_details = result.cancellation_details
        print(f"❌ AZURE TTS CANCELED: {cancellation_details.reason}")
        if cancellation_details.reason == speechsdk.CancellationReason.Error:
            print(f"❌ AZURE TTS ERROR DETAILS: {cancellation_details.error_details}")
        return None
    return None

# ✅ ADD THIS NEW FUNCTION
async def speech_to_text_from_bytes(audio_bytes: bytes) -> str:
    """Transcribes speech from in-memory audio bytes using Azure."""
    if not speech_config:
        print("❌ AZURE STT ERROR: speech_config is not available.")
        return "Error: Speech service not configured."

    # Creates an audio stream from the binary audio data
    audio_stream = speechsdk.audio.PushAudioInputStream()
    audio_config = speechsdk.audio.AudioConfig(stream=audio_stream)

    # Creates a speech recognizer
    speech_recognizer = speechsdk.SpeechRecognizer(speech_config=speech_config, audio_config=audio_config)

    # Write the audio data to the stream and close it
    audio_stream.write(audio_bytes)
    audio_stream.close()

    print("🎤 AZURE STT INFO: Transcribing audio...")

   # This is the corrected code
    future = speech_recognizer.recognize_once_async()
    result = await asyncio.to_thread(future.get)

    # Check the result
    if result.reason == speechsdk.ResultReason.RecognizedSpeech:
        print(f"✅ AZURE STT SUCCESS: Recognized: {result.text}")
        return result.text
    elif result.reason == speechsdk.ResultReason.NoMatch:
        print("❌ AZURE STT NOMATCH: No speech could be recognized.")
        return ""
    elif result.reason == speechsdk.ResultReason.Canceled:
        cancellation_details = result.cancellation_details
        print(f"❌ AZURE STT CANCELED: Reason: {cancellation_details.reason}")
        if cancellation_details.reason == speechsdk.CancellationReason.Error:
            print(f"❌ AZURE STT ERROR DETAILS: {cancellation_details.error_details}")
        return "Error during transcription."

    return ""
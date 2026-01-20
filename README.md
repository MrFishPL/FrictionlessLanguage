<div>
    <a href="https://www.loom.com/share/007c18efd03945caa9416f26d644531a">
      <p>Introducing My New App for Podcast Translation and Vocabulary</p>
    </a>
    <a href="https://www.loom.com/share/007c18efd03945caa9416f26d644531a">
      <img style="max-width:300px;" src="https://cdn.loom.com/sessions/thumbnails/007c18efd03945caa9416f26d644531a-04f52773140939f2-full-play.gif#t=0.1">
    </a>
  </div>

# Flungus 🍄

Flungus is a macOS 14.4+ menu bar app that captures system audio, streams it to ElevenLabs for realtime transcription, and shows live captions in a notch-style overlay. You can select words or phrases in the overlay to trigger an OpenAI-powered translation into the configured target language.

## What it does
- Captures system audio using the macOS process tap APIs.
- Streams audio to ElevenLabs realtime STT for live captions.
- Displays captions in a floating notch panel.
- Supports selection-based translation via OpenAI with structured output.
- Stores API keys locally for quick startup.

## Requirements
- macOS 14.4 or newer.
- ElevenLabs API key.
- OpenAI API key.

## Quick start
1. Build the app:
   ```
   swift build
   ```
2. Run it from Xcode or your preferred workflow.
3. Enter API keys when prompted.

<div>
    <a href="https://www.loom.com/share/4bc1e6b1ad334c0aaeb53dac6286c6b1">
      <p>Revolutionizing Language Learning with a New App! 🌍 - Watch Video</p>
    </a>
    <a href="https://www.loom.com/share/4bc1e6b1ad334c0aaeb53dac6286c6b1">
      <img style="max-width:300px;" src="https://cdn.loom.com/sessions/thumbnails/4bc1e6b1ad334c0aaeb53dac6286c6b1-3ccdb96364e157bb-full-play.gif#t=0.1">
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

## Configuration
- Target translation language is currently hardcoded in `Sources/transcribtion/AppConfig.swift`.
- API keys are stored in user defaults and can be set/removed from the status bar menu.

## TODO
1. Do not pause if already paused
2. Improve the prompt

# VoxSlice

One-click meeting recording → structured AI analysis in a Markdown file you can share immediately.

VoxSlice is a native macOS menu bar app that records audio from both microphone and system audio, transcribes it using OpenAI's STT API, and uses AI to extract summaries, action items, decisions, and key topics. Results are saved as timestamped Markdown files.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15 or later
- Apple Silicon (M1/M2/M3/M4) or Intel Mac
- OpenAI API key (for transcription and analysis)

## Build

### 1. Clone the repository

```bash
git clone <repo-url>
cd VoxSlice
```

### 2. Open in Xcode

```bash
open VoxSlice.xcodeproj
```

### 3. Resolve dependencies

Xcode > File > Packages > Resolve Package Versions

### 4. Build and run

Press `Cmd + R` in Xcode, or build from the command line:

```bash
xcodebuild -project VoxSlice.xcodeproj \
  -scheme VoxSlice \
  -configuration Debug \
  build
```

The built app will be in `DerivedData/VoxSlice/Build/Products/Debug/VoxSlice.app`.

## Permissions

On first launch, VoxSlice will request two macOS permissions:

1. **Screen Recording** — required to capture system audio (Zoom, Meet, etc.). After granting, the app needs to restart.
2. **Microphone** — required to record your voice during meetings.

Both permissions are prompted automatically on first launch with guided instructions.

## Configuration

Open Settings via `Cmd + ,` or the menu bar icon. You need to:

1. **Set output folder** — where Markdown analysis files are saved
2. **Configure STT provider** — enter your OpenAI API key for transcription
3. **Configure AI provider** — enter your OpenAI API key for meeting analysis

API keys are stored securely in macOS Keychain, not in plain-text files.

## Package for Distribution

### Archive

```bash
xcodebuild -project VoxSlice.xcodeproj \
  -scheme VoxSlice \
  -configuration Release \
  -archivePath build/VoxSlice.xcarchive \
  archive
```

### Export .app

```bash
xcodebuild -exportArchive \
  -archivePath build/VoxSlice.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export
```

### Create DMG (optional)

Install [create-dmg](https://github.com/create-dmg/create-dmg):

```bash
brew install create-dmg
```

Then:

```bash
create-dmg \
  --volname "VoxSlice" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "VoxSlice.app" 175 190 \
  --app-drop-link 425 190 \
  "build/VoxSlice.dmg" \
  "build/export/VoxSlice.app"
```

## Install

### From DMG

1. Open `VoxSlice.dmg`
2. Drag VoxSlice to the Applications folder
3. Launch from Applications (first launch: right-click > Open to bypass Gatekeeper)

### From source

Copy the built app to Applications:

```bash
cp -R build/export/VoxSlice.app /Applications/
```

## Run

After installation, VoxSlice runs as a **menu bar app** — it does not appear in the Dock.

- Click the waveform icon in the menu bar to access controls
- `Cmd + ,` to open Settings
- `Cmd + Q` to quit

## Technology

- **Swift / SwiftUI** — native macOS UI
- **ScreenCaptureKit** — system audio capture
- **AVAudioEngine** — microphone capture
- **OpenAI gpt-4o-transcribe** — speech-to-text
- **OpenAI Chat Completions** — meeting analysis
- **Keychain Services** — secure API key storage

## License

All rights reserved.

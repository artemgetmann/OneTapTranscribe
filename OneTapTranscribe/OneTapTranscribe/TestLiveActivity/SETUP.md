# Test A: Live Activity Setup

## Create Xcode Project

1. Open Xcode → File → New → Project
2. Choose **App** (iOS)
3. Settings:
   - Product Name: `TestLiveActivity`
   - Bundle ID: `com.yourname.TestLiveActivity`
   - Interface: **SwiftUI**
   - Language: **Swift**
4. Save to `/Users/user/Programming_Projects/OneTapTranscribe/`

## Add Widget Extension (Required for Live Activity)

1. File → New → Target
2. Choose **Widget Extension**
3. Settings:
   - Product Name: `RecordingWidget`
   - **Uncheck** "Include Configuration App Intent"
   - **Check** "Include Live Activity"
4. Click Finish → Activate scheme

## Replace Generated Files

Delete the auto-generated files and use the ones I created:

### Main App Target
- Replace `ContentView.swift` with my version
- Replace `TestLiveActivityApp.swift` with my version
- Add `RecordingAttributes.swift` to **both** targets (main app AND widget)
- Add `Stores/RecordingStateStore.swift` to main app target
- Add all files under `Services/` to main app target

### Widget Extension Target
- Replace the generated widget file with `OneTapTranscribeWidgetExtension/RecordingLiveActivityWidget.swift`
- Ensure bundle entry is `OneTapTranscribeWidgetExtension/OneTapTranscribeWidgetExtensionBundle.swift`
- Make sure `RecordingAttributes.swift` is in this target too

## Configure Info.plist

Add to main app's Info.plist:
```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSMicrophoneUsageDescription</key>
<string>OneTapTranscribe needs microphone access to record audio for transcription.</string>
<key>TRANSCRIPTION_BASE_URL</key>
<string>http://127.0.0.1:8000</string>
```

## Backend Proxy

From repo root:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
export OPENAI_API_KEY="YOUR_KEY"
uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload
```

If testing on physical iPhone, replace `TRANSCRIPTION_BASE_URL` with your Mac's LAN IP:
- Example: `http://192.168.1.20:8000`

## Build & Run

1. Select iPhone 15 Pro simulator (has Dynamic Island)
2. Build and run
3. Tap "Start"
4. Press Home, open Safari
5. **Observe:** Is the Live Activity visible?
6. Stop recording and verify transcript is copied to clipboard

## Also Test on iPad

1. Change simulator to iPad
2. Repeat test
3. **Observe:** Where does Live Activity appear?

## Expected Results

- **iPhone 14 Pro+**: Dynamic Island shows timer + compact view
- **iPad**: Live Activity only on Lock Screen, NOT floating while using other apps

# Architecture Patterns

**Domain:** Mac desktop audio recording + AI transcription/analysis
**Researched:** 2026-04-06

## Recommended Architecture

VoxSlice uses a **layered pipeline architecture** with clear separation between capture, processing, storage, and presentation. Data flows in one direction: audio capture -> file persistence -> async processing (transcription then analysis) -> Markdown output. The UI observes state changes reactively.

```
┌─────────────────────────────────────────────────────────────────┐
│                        SwiftUI App Layer                        │
│  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ Dashboard │  │ Recording │  │ Settings │  │ History List  │  │
│  │   View    │  │   View    │  │   View   │  │    View       │  │
│  └─────┬─────┘  └─────┬─────┘  └────┬─────┘  └──────┬────────┘  │
│        │              │             │                │           │
│  ┌─────▼──────────────▼─────────────▼────────────────▼────────┐  │
│  │                  ViewModel / State Layer                    │  │
│  │  ( @Observable classes, shared via @Environment )           │  │
│  └─────────────────────────┬───────────────────────────────────┘  │
└────────────────────────────┼─────────────────────────────────────┘
                             │
┌────────────────────────────┼─────────────────────────────────────┐
│                     Service Layer                                │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐  │
│  │   Audio       │  │  Processing  │  │     Storage           │  │
│  │   Capture     │  │  Pipeline    │  │     Service           │  │
│  │   Service     │  │              │  │                       │  │
│  │ ┌───────────┐│  │ ┌──────────┐ │  │  ┌─────────────────┐  │  │
│  │ │SystemAudio││  │ │STT Client│ │  │  │ File Manager    │  │  │
│  │ │  (SCK)    ││  │ │(Whisper) │ │  │  │ (audio + md)    │  │  │
│  │ ├───────────┤│  │ ├──────────┤ │  │  └─────────────────┘  │  │
│  │ │MicAudio   ││  │ │AI Client │ │  │                       │  │
│  │ │(AVAudio)  ││  │ │(GPT-4o)  │ │  │                       │  │
│  │ └───────────┘│  │ └──────────┘ │  │                       │  │
│  └──────────────┘  └──────────────┘  └───────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │                   Hotkey Service                             ││
│  │          (Global keyboard shortcut via Carbon/NSEvent)       ││
│  └──────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────┘
                             │
┌────────────────────────────┼─────────────────────────────────────┐
│                     Persistence Layer                            │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────┐    │
│  │ Audio Files  │  │  SwiftData   │  │  Markdown Files      │    │
│  │ (.wav/.m4a)  │  │  (metadata)  │  │  (analysis output)   │    │
│  └─────────────┘  └──────────────┘  └──────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **AudioCaptureService** | Captures system audio via ScreenCaptureKit and microphone audio via AVAudioEngine. Produces audio file on disk when recording stops. | RecordingViewModel (state updates), StorageService (file writes) |
| **ProcessingPipeline** | Orchestrates post-recording async workflow: upload to STT, receive transcript, send transcript to AI for analysis. Manages retries and error handling. | RecordingViewModel (progress updates), StorageService (read audio, write results) |
| **STTClient** | Calls OpenAI Whisper API with audio file. Returns timestamped transcript text. | ProcessingPipeline (called by) |
| **AIClient** | Calls OpenAI Chat Completions API with transcript. Returns structured analysis (summary, action items, decisions, topics). | ProcessingPipeline (called by) |
| **StorageService** | Manages file I/O: audio files, Markdown output, app metadata (SwiftData). Handles folder creation, file naming, cleanup. | AudioCaptureService, ProcessingPipeline, HistoryViewModel |
| **HotkeyService** | Registers global keyboard shortcut via Carbon API or NSEvent.addGlobalMonitorForEvents. Triggers start/stop recording. | AudioCaptureService (start/stop) |
| **SettingsManager** | Stores user preferences (API keys, output folder, hotkey binding) using UserDefaults or @AppStorage. | SettingsView, all services that need config |
| **RecordingViewModel** | Manages recording state machine (idle -> recording -> processing -> complete). Coordinates AudioCaptureService and ProcessingPipeline. | UI views (observed), AudioCaptureService, ProcessingPipeline |
| **HistoryViewModel** | Loads recording history from SwiftData, provides data for dashboard list. | StorageService (reads metadata), UI views (observed) |
| **SwiftUI Views** | Renders dashboard, recording controls, settings, history. Binds to ViewModels via @Observable. | ViewModels only (never services directly) |

### Data Flow

**Recording Flow:**

```
1. User presses hotkey or clicks "Record"
2. RecordingViewModel transitions state: idle -> recording
3. AudioCaptureService starts two parallel capture sessions:
   a. ScreenCaptureKit stream with capturesAudio=true -> system audio samples
   b. AVAudioEngine with inputNode -> microphone audio samples
4. Both streams write to a shared AVAudioFile (or separate files merged later)
5. User presses hotkey or clicks "Stop"
6. AudioCaptureService stops streams, finalizes audio file on disk
7. RecordingViewModel transitions state: recording -> processing
8. ProcessingPipeline begins:
   a. STTClient sends audio file to OpenAI Whisper API
   b. Whisper returns transcript with timestamps
   c. StorageService saves raw transcript
   d. AIClient sends transcript to OpenAI Chat Completions with analysis prompt
   e. AI returns structured analysis (summary, action items, decisions, topics)
   f. StorageService writes Markdown file to output folder
   g. SwiftData records metadata entry (date, duration, file paths)
9. RecordingViewModel transitions state: processing -> complete
10. UI updates via @Observable change notification
```

**Key data formats at each stage:**

| Stage | Format | Location |
|-------|--------|----------|
| Raw audio capture | CMSampleBuffer (in-memory) | AudioCaptureService |
| Finalized audio file | .m4a (AAC) or .wav (PCM) | ~/Library/Application Support/VoxSlice/audio/ |
| Raw transcript | JSON (Whisper response) | Stored in SwiftData model |
| AI analysis | Structured JSON (parsed from GPT response) | In-memory, then rendered to Markdown |
| Final output | .md (Markdown file) | User-configured output folder |

## Patterns to Follow

### Pattern 1: Actor-Isolated Services
**What:** Each service (AudioCaptureService, ProcessingPipeline, StorageService) is a Swift `actor` to enforce thread safety without manual lock management. Audio capture callbacks arrive on background dispatch queues, so actor isolation prevents data races.
**When:** Every service that manages mutable state accessed from multiple threads.
**Example:**
```swift
actor AudioCaptureService {
    private var isRecording = false
    private var stream: SCStream?
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?

    func startRecording() async throws { ... }
    func stopRecording() async throws -> URL { ... }
}
```

### Pattern 2: Async Pipeline with Progress Reporting
**What:** The processing pipeline uses `AsyncStream` or structured concurrency (`async let` / task groups) to chain STT and AI analysis steps. Progress is reported back to the UI via an `@Observable` state object.
**When:** Post-recording processing (transcription + analysis).
**Example:**
```swift
@Observable
class RecordingViewModel {
    enum ProcessingStep {
        case idle, recording, transcribing, analyzing, complete, failed(Error)
    }
    var processingStep: ProcessingStep = .idle

    func processRecording(audioURL: URL) async {
        processingStep = .transcribing
        let transcript = try await sttClient.transcribe(audioURL: audioURL)

        processingStep = .analyzing
        let analysis = try await aiClient.analyze(transcript: transcript)

        try await storageService.saveMarkdown(analysis: analysis, for: recording)
        processingStep = .complete
    }
}
```

### Pattern 3: ScreenCaptureKit for System Audio
**What:** Use ScreenCaptureKit (available macOS 12.3+) to capture system audio. This is the ONLY Apple-sanctioned way to capture system audio on macOS. It requires the Screen Recording permission. Configure `SCStreamConfiguration` with `capturesAudio = true` and `excludesCurrentProcessAudio = true`. Add a stream output of type `.audio` to receive `CMSampleBuffer` containing audio data.
**When:** System audio capture (Zoom, Meet, browser audio, etc.).
**Example:**
```swift
// From Apple's official sample code
var config = SCStreamConfiguration()
config.capturesAudio = true
config.excludesCurrentProcessAudio = true
config.captureMicrophone = false  // Mic handled separately via AVAudioEngine

let filter = SCContentFilter(display: mainDisplay,
                             excludingApplications: [],
                             exceptingWindows: [])

let stream = SCStream(filter: filter, configuration: config, delegate: self)
try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
try await stream.startCapture()
```

### Pattern 4: AVAudioEngine for Microphone Capture
**What:** Use `AVAudioEngine.inputNode` to capture microphone audio. Tap the input node to receive audio buffers in real-time. Write buffers to an `AVAudioFile` for persistence.
**When:** Microphone audio capture.
**Example:**
```swift
let audioEngine = AVAudioEngine()
let inputNode = audioEngine.inputNode
let format = inputNode.outputFormat(forBus: 0)

let audioFile = try AVAudioFile(forWriting: fileURL,
                                settings: format.settings)

inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
    try? audioFile.write(from: buffer)
}

try audioEngine.start()
```

### Pattern 5: Two-Source Audio Mixing Strategy
**What:** System audio (ScreenCaptureKit) and microphone audio (AVAudioEngine) arrive as separate streams with potentially different sample rates. Strategy: keep them as separate files during capture, then merge post-capture using AVAudioEngine's offline rendering mode, or upload both to Whisper and merge transcripts by timestamp. The simpler v1 approach: upload the mixed-down file (use AVAudioEngine to mix both sources into one file) or upload system audio only (which captures the meeting) and mic audio separately.
**When:** Always -- this is a core architectural decision for dual-source capture.
**Recommendation for v1:** Capture both streams separately. Upload system audio to Whisper (it contains the meeting content). Keep mic audio as a secondary file. This avoids complex real-time mixing and the system audio already captures what matters most (the other meeting participants). If the user's own voice matters, concatenate or interleave post-capture.

### Pattern 6: SwiftData for Recording Metadata
**What:** Use SwiftData (available macOS 14+) to persist recording metadata: UUID, date, duration, audio file path, transcript text, analysis file path, processing status. This provides querying, sorting, and filtering for the history view without manual Core Data boilerplate.
**When:** Recording history and metadata storage.
**Example:**
```swift
@Model
class Recording {
    var id: UUID
    var createdAt: Date
    var duration: TimeInterval
    var audioFilePath: String
    var transcriptFilePath: String?
    var markdownFilePath: String?
    var status: ProcessingStatus

    enum ProcessingStatus: String, Codable {
        case recording, transcribing, analyzing, complete, failed
    }
}
```

### Pattern 7: Menu Bar App with Optional Window
**What:** VoxSlice should run as a menu bar utility (via `MenuBarExtra`) with an optional full window for dashboard/history. Recording can be triggered from the menu bar icon or global hotkey without the main window being visible. This matches user expectation for a background recording tool.
**When:** App lifecycle -- the menu bar is the primary interface.
**Example:**
```swift
@main
struct VoxSliceApp: App {
    var body: some Scene {
        MenuBarExtra("VoxSlice", systemImage: "waveform") {
            MenuBarView()
                .environmentObject(recordingManager)
        }
        WindowGroup {
            DashboardView()
                .environmentObject(recordingManager)
        }
        Settings {
            SettingsView()
        }
    }
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Mixing UI Code with Service Logic
**What:** Putting API calls, file I/O, or audio capture logic inside SwiftUI views or ViewModels that also manage view state.
**Why bad:** Makes testing impossible, creates tight coupling, causes UI freezes when synchronous work blocks the main thread.
**Instead:** Keep ViewModels thin (state + method stubs that delegate to services). All real work happens in service-layer actors/classes. ViewModels only coordinate and update @Observable state.

### Anti-Pattern 2: Real-Time Audio Processing in the Main Thread
**What:** Handling CMSampleBuffer callbacks or AVAudioEngine taps on the main thread.
**Why bad:** Audio callbacks have hard real-time deadlines. Missing them causes audio glitches, dropped samples, or crashes. The main thread also handles UI rendering and can be blocked by layout or animations.
**Instead:** ScreenCaptureKit accepts a `sampleHandlerQueue` parameter -- always provide a dedicated DispatchQueue. AVAudioEngine taps fire on a background thread by default but document this explicitly. Never dispatch UI updates from these callbacks; use @Observable or MainActor to hop back.

### Anti-Pattern 3: Storing API Keys in Plaintext or Keychain Without User Awareness
**What:** Hardcoding API keys, storing in UserDefaults without encryption, or using Keychain without clear UX.
**Why bad:** API keys are billing-attached credentials. Users need to understand where they are stored and be able to update/clear them.
**Instead:** Use macOS Keychain via `Security` framework for persistent storage. Provide a clear Settings UI where users enter, view (masked), and delete their keys. On first launch, guide users through key setup.

### Anti-Pattern 4: Blocking the Recording Pipeline on Network Calls
**What:** Starting transcription during an active recording, or pausing recording while waiting for an API response.
**Why bad:** Recording must be reliable above all else. Network latency, API errors, or rate limits must never cause recording interruptions.
**Instead:** Recording is fully independent from processing. The pipeline is strictly sequential: record (complete) -> then process. Processing failures do not affect the saved audio file. Failed processing can be retried later.

### Anti-Pattern 5: Single Monolithic Audio File Without Segmentation
**What:** Writing all audio to one massive file for multi-hour meetings.
**Why bad:** Files over 25MB cannot be uploaded to Whisper API in a single request. Long recordings create huge files, slow uploads, and cannot be retried partially.
**Instead:** Either chunk audio into segments (e.g., 10-minute files) during recording, or post-process to split before upload. Whisper has a 25MB file size limit. Plan for chunking from day one.

## Scalability Considerations

| Concern | At 100 recordings | At 1K recordings | At 10K+ recordings |
|---------|-------------------|-------------------|---------------------|
| **Audio file storage** | ~1-5 GB (50MB/hr * 20 sessions) | ~10-50 GB | ~100+ GB -- need cleanup/archival policy |
| **SwiftData query perf** | Instant | Fast | May need indexed queries, pagination |
| **Whisper API limits** | Single file upload fine | May hit rate limits on batch processing | Need queue system, backoff, retry logic |
| **UI responsiveness** | Simple list is fine | Consider lazy loading | Virtualized list, search/filter required |
| **Menu bar usability** | Simple dropdown is fine | Recent recordings in menu | Search in menu, or menu bar becomes just a trigger |

## Build Order (Dependencies Between Components)

The following order reflects which components must exist before others can function. This should directly inform the project's phase structure.

```
1. Project scaffolding + SwiftUI app shell
   |
2a. StorageService (file I/O, SwiftData models)     2b. SettingsManager (UserDefaults/Keychain)
   |                                                    |
3. AudioCaptureService (depends on StorageService for file writes)
   |
4. HotkeyService (depends on AudioCaptureService for start/stop)
   |
5. STTClient (standalone HTTP client, depends on SettingsManager for API key)
   |
6. AIClient (standalone HTTP client, depends on SettingsManager for API key)
   |
7. ProcessingPipeline (depends on STTClient, AIClient, StorageService)
   |
8. ViewModels (depends on AudioCaptureService, ProcessingPipeline, StorageService)
   |
9. SwiftUI Views (depends on ViewModels)
   |
10. Packaging + Distribution (DMG, code signing, notarization)
```

**Critical path:** AudioCaptureService -> ProcessingPipeline -> ViewModels -> Views. This is the longest chain and determines minimum build time.

**Parallelizable work:** STTClient and AIClient can be built independently (they are stateless HTTP clients). SettingsManager and StorageService can be built in parallel.

## Sources

- Apple ScreenCaptureKit documentation: https://developer.apple.com/documentation/screencapturekit (HIGH confidence)
- Apple "Capturing screen content in macOS" sample: https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos (HIGH confidence)
- Apple AVFAudio documentation: https://developer.apple.com/documentation/avfaudio (HIGH confidence)
- Apple AVAudioEngine documentation: https://developer.apple.com/documentation/avfaudio/avaudioengine (HIGH confidence)
- Apple Swift Concurrency documentation: https://developer.apple.com/documentation/swift/concurrency (HIGH confidence)
- Apple SwiftUI App documentation: https://developer.apple.com/documentation/swiftui/app (HIGH confidence)
- Whisper API 25MB file size limit: OpenAI platform docs (MEDIUM confidence -- verified from training data, should confirm at implementation time)
- SwiftData availability (macOS 14+): Apple WWDC 2023 announcements (HIGH confidence)
- ScreenCaptureKit audio capture requires Screen Recording permission: Apple documentation (HIGH confidence)
- MenuBarExtra for menu bar apps: SwiftUI documentation (HIGH confidence)

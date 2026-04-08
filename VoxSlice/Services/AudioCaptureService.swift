import Foundation
import AVFoundation
import CoreMedia
import CoreAudio
import ScreenCaptureKit
import Combine

// MARK: - Notification Names

extension Notification.Name {
    static let voxsliceRecordingStopped = Notification.Name("com.voxslice.recordingStopped")
    static let voxsliceDeviceChanged = Notification.Name("com.voxslice.deviceChanged")
    static let voxsliceSilenceDetected = Notification.Name("com.voxslice.silenceDetected")
}

// MARK: - AudioCaptureService

@Observable
@MainActor
final class AudioCaptureService {

    // MARK: - Published State

    var state: RecordingState = .idle
    var currentRecording: RecordingInfo?
    var elapsedDuration: TimeInterval = 0
    var audioLevels: (mic: Float, system: Float) = (0, 0)

    // MARK: - Dependencies

    private let storageService: StorageService
    private let permissionManager: PermissionManager

    // MARK: - Internal Capture Components

    private var audioEngine: AVAudioEngine?
    internal var micAudioFile: AVAudioFile?
    internal var systemAudioFile: AVAudioFile?
    private var screenCaptureStream: SCStream?
    private let audioQueue = DispatchQueue(label: "com.voxslice.audio", qos: .userInitiated)

    // Target audio format for file output
    private var targetFormat: AVAudioFormat!

    // Silence detection
    private var silenceStartTime: Date?
    private var silenceCheckTimer: Timer?

    // Device monitoring
    private var cancellables: [AnyCancellable] = []

    // Elapsed timer
    private var durationTimer: Timer?

    // Stream output handler (keeps strong reference)
    private var streamOutput: AudioStreamOutput?

    // MARK: - Initialization

    init(storageService: StorageService, permissionManager: PermissionManager) {
        self.storageService = storageService
        self.permissionManager = permissionManager

        // Create target format: 44100 Hz, 1 channel, float32
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AppConstants.audioSampleRate,
            channels: 1,
            interleaved: false
        )!

        setupDeviceChangeObservers()
    }

    // MARK: - Device Change Observers
    private func setupDeviceChangeObservers() {
        // Listen for audio device changes via system notification
        NotificationCenter.default.publisher(
            for: NSNotification.Name("AVAudioApplicationDeviceListChangedNotification")
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.handleDeviceChange()
        }
        .store(in: &cancellables)
    }
    // MARK: - Start Recording
    func startRecording() throws {
        // Step 1: Check permissions
        guard permissionManager.allPermissionsGranted else {
            state = .failed(.noPermission)
            throw RecordingError.noPermission
        }

        // Step 2: Generate timestamp-based filenames per D-10
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = AppConstants.recordingTimestampFormat
        let timestamp = dateFormatter.string(from: Date.now)

        let recordingsDir = storageService.directoryURL(for: AppConstants.recordingsDir)
        let micFileURL = recordingsDir.appendingPathComponent("\(timestamp)_mic.\(AppConstants.audioFileExtension)")
        let systemFileURL = recordingsDir.appendingPathComponent("\(timestamp)_system.\(AppConstants.audioFileExtension)")

        // Step 3: Create RecordingInfo
        let micDeviceName = getMicDeviceName()
        let systemDeviceName = getSystemAudioDeviceName()

        let recording = RecordingInfo(
            startTime: .now,
            micFilePath: micFileURL.path,
            systemFilePath: systemFileURL.path,
            state: .recording,
            micDeviceName: micDeviceName,
            systemAudioDeviceName: systemDeviceName
        )

        // Step 4: Create audio files with AAC settings per D-01, D-03
        let fileSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: AppConstants.audioSampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: AppConstants.audioBitrate
        ]

        do {
            micAudioFile = try AVAudioFile(forWriting: micFileURL, settings: fileSettings)
            systemAudioFile = try AVAudioFile(forWriting: systemFileURL, settings: fileSettings)
        } catch {
            state = .failed(.fileWriteFailed(error.localizedDescription))
            throw RecordingError.fileWriteFailed(error.localizedDescription)
        }

        // Step 5: Start microphone capture via AVAudioEngine
        var micStarted = false
        do {
            try startMicCapture()
            micStarted = true
        } catch {
            print("[AudioCaptureService] Microphone capture failed to start: \(error.localizedDescription)")
        }

        // Step 6: Start system audio capture via ScreenCaptureKit
        var systemStarted = false
        do {
            try startSystemAudioCapture()
            systemStarted = true
        } catch {
            print("[AudioCaptureService] System audio capture failed to start: \(error.localizedDescription)")
        }

        // Step 7: If both failed, throw error
        if !micStarted && !systemStarted {
            micAudioFile = nil
            systemAudioFile = nil
            state = .failed(.captureStartFailed("Both microphone and system audio capture failed to start"))
            throw RecordingError.captureStartFailed("Both microphone and system audio capture failed to start")
        }

        // Step 8: Start timers
        startDurationTimer()
        startSilenceDetectionTimer()

        // Step 9: Update state
        currentRecording = recording
        state = .recording
    }

    // MARK: - Microphone Capture
    private func startMicCapture() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw RecordingError.captureStartFailed("Failed to create audio converter for microphone input")
        }

        let targetFmt = targetFormat!
        let micFile = micAudioFile!

        let bufferSize: AVAudioFrameCount = 1024

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard self != nil else { return }

            // Convert buffer to target format
            let ratio = targetFmt.sampleRate / buffer.format.sampleRate
            let convertedFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            guard convertedFrameCapacity > 0 else { return }

            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFmt, frameCapacity: convertedFrameCapacity) else { return }

            var error: NSError?
            var inputFramesLeft = buffer.frameLength

            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                if inputFramesLeft > 0 {
                    outStatus.pointee = .haveData
                    inputFramesLeft = 0
                    return buffer
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }

            if let error = error {
                print("[AudioCaptureService] Mic format conversion error: \(error.localizedDescription)")
                return
            }

            // Write to file immediately ( no accumulation in memory per D-04
            do {
                try micFile.write(from: convertedBuffer)
            } catch {
                print("[AudioCaptureService] Mic file write error: \(error.localizedDescription)")
                return
            }

            // Calculate RMS level for metering
            let level = Self.calculateRMS(for: convertedBuffer)

            // Update audio level on main thread
            DispatchQueue.main.async {
                self?.audioLevels.mic = level
            }
        }

        try engine.start()
        audioEngine = engine
    }
    // MARK: - System Audio Capture
    private func startSystemAudioCapture() throws {
        let output = AudioStreamOutput(service: self)
        streamOutput = output

        Task {
            do {
                // Get shareable content - target main display
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)

                guard let mainDisplay = content.displays.first else {
                    throw RecordingError.captureStartFailed("No display found for system audio capture")
                }

                let filter = SCContentFilter(display: mainDisplay, excludingApplications: [], exceptingWindows: [])

                var config = SCStreamConfiguration()
                config.capturesAudio = true
                config.excludesCurrentProcessAudio = true

                // Do NOT set capturesMicrophone - mic handled separately via AVAudioEngine

                let stream = SCStream(filter: filter, configuration: config, delegate: output)
                try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: audioQueue)
                try await stream.startCapture()
                await MainActor.run {
                    self.screenCaptureStream = stream
                    self.streamOutput = output
                }
            } catch {
                print("[AudioCaptureService] System audio capture failed: \(error.localizedDescription)")
                throw RecordingError.captureStartFailed("System audio: \(error.localizedDescription)")
            }
        }
    }
    // MARK: - Stop Recording
    func stopRecording() throws -> RecordingInfo {
        guard state == .recording || state == .stopping else {
            throw RecordingError.captureStartFailed("Not currently recording")
        }

        state = .stopping

        // Stop AVAudioEngine
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            audioEngine = nil
        }

        // Stop ScreenCaptureKit stream
        if let stream = screenCaptureStream {
            Task {
                try? await stream.stopCapture()
            }
            screenCaptureStream = nil
            streamOutput = nil
        }

        // Close audio files
        micAudioFile = nil
        systemAudioFile = nil
        // Stop timers
        stopTimers()
        // Update recording info
        var recording = currentRecording ?? RecordingInfo(
            micFilePath: "",
            systemFilePath: ""
        )
        recording.endTime = .now
        recording.state = .completed
        // Save metadata JSON file per D-11
        saveMetadata(for: recording)
        // Update state
        currentRecording = recording
        state = .completed
        audioLevels = (0, 0)
        // Post notification
        NotificationCenter.default.post(name: .voxsliceRecordingStopped, object: nil)
        return recording
    }
    // MARK: - Silence Detection
    private func startSilenceDetectionTimer() {
        silenceStartTime = nil
        silenceCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSilence()
            }
        }
    }

    private func checkSilence() {
        let threshold = AppConstants.silenceThreshold
        if audioLevels.mic < threshold && audioLevels.system < threshold {
            if silenceStartTime == nil {
                silenceStartTime = .now
            }
            if let startTime = silenceStartTime,
               Date.now.timeIntervalSince(startTime) >= AppConstants.silenceDetectionTimeout {
                stopRecordingDueToSilence()
            }
        } else {
            silenceStartTime = nil
        }
    }
    private func stopRecordingDueToSilence() {
        currentRecording?.silenceDetected = true
        do {
            _ = try stopRecording()
            NotificationCenter.default.post(
                name: .voxsliceSilenceDetected,
                object: nil,
                userInfo: ["message": "Recording stopped: no audio detected for 30 seconds"]
            )
        } catch {
            state = .failed(.silenceDetected)
        }
    }
    // MARK: - Device Change Handling
    private func handleDeviceChange() {
        guard state == .recording else { return }
        let newMicDevice = getMicDeviceName()
        let oldMicDevice = currentRecording?.micDeviceName ?? ""
        // Log the device change
        if newMicDevice != oldMicDevice {
            let change = AudioDeviceChange(
                deviceName: newMicDevice,
                changeType: oldMicDevice.isEmpty ? .connected : .disconnected,
                timestamp: .now
            )
            currentRecording?.deviceChanges.append(change)
            // Restart AVAudioEngine with new input per D-08
            do {
                try restartMicCapture()
                currentRecording?.micDeviceName = newMicDevice
                NotificationCenter.default.post(
                    name: .voxsliceDeviceChanged,
                    object: nil,
                    userInfo: ["deviceName": newMicDevice, "message": "Switched to \(newMicDevice)"]
                )
            } catch {
                print("[AudioCaptureService] Failed to restart mic after device change: \(error.localizedDescription)")
            }
        }
    }
    private func restartMicCapture() throws {
        // Stop current engine
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            audioEngine = nil
        }
        // Create new engine with new input
        try startMicCapture()
    }
    // MARK: - Duration Timer
    private func startDurationTimer() {
        elapsedDuration = 0
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.state == .recording else { return }
            self.elapsedDuration += 1.0
        }
    }
    // MARK: - Timer Cleanup
    private func stopTimers() {
        durationTimer?.invalidate()
        durationTimer = nil
        silenceCheckTimer?.invalidate()
        silenceCheckTimer = nil
        silenceStartTime = nil
    }
    // MARK: - Metadata Saving
    private func saveMetadata(for recording: RecordingInfo) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(recording)
            let metadataURL = URL(fileURLWithPath: recording.metadataFilePath)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            print("[AudioCaptureService] Failed to save metadata: \(error.localizedDescription)")
        }
    }
    // MARK: - Utility
    private func getMicDeviceName() -> String {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr else { return "Unknown Microphone" }
        return getDeviceName(deviceID: deviceID)
    }
    private func getSystemAudioDeviceName() -> String {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr else { return "Unknown Output" }
        return getDeviceName(deviceID: deviceID)
    }
    private func getDeviceName(deviceID: AudioDeviceID) -> String {
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &name
        )
        guard status == noErr else { return "Unknown Device" }
        return name as String
    }
    /// Calculate RMS (root mean square) of an audio buffer for level metering
    nonisolated static func calculateRMS(for buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        return sqrt(sum / Float(frameLength))
    }
}

// MARK: - AudioStreamOutput (SCStreamOutput and SCStreamDelegate)
private class AudioStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    private weak var service: AudioCaptureService?
    private let targetFormat: AVAudioFormat

    init(service: AudioCaptureService) {
        self.service = service
        self.targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AppConstants.audioSampleRate,
            channels: 1,
            interleaved: false
        )!
    }
    // MARK: - SCStreamDelegate
    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        print("[AudioStreamOutput] Stream stopped with error: \(error.localizedDescription)")
        Task { @MainActor in
            guard let service = service else { return }
            if service.state == .recording {
                _ = try? service.stopRecording()
            }
        }
    }
    // MARK: - SCStreamOutput
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard let service = service else { return }
        // Extract audio buffer from CMSampleBuffer
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let length = CMBlockBufferGetDataLength(blockBuffer)
        // Get audio format description from CMSampleBuffer
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else { return }
        let sampleRate = asbd.pointee.mSampleRate
        let channels = asbd.pointee.mChannelsPerFrame
        // Create AVAudioFormat from the stream's format
        guard let streamFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ) else { return }
        // Calculate number of frames
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        guard numSamples > 0 else { return }
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: streamFormat, frameCapacity: AVAudioFrameCount(numSamples)) else { return }
        pcmBuffer.frameLength = AVAudioFrameCount(numSamples)
        // Copy raw data into the PCM buffer
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: nil, dataPointerOut: &dataPointer)
        guard status == kCMBlockBufferNoErr, let dataPtr = dataPointer else {
            print("[AudioStreamOutput] Failed to get data pointer from block buffer")
            return
        }
        let bytesToCopy = min(Int(pcmBuffer.frameLength) * Int(channels) * MemoryLayout<Float>.size, length)
        memcpy(pcmBuffer.floatChannelData![0], dataPtr, bytesToCopy)
        // Convert to target format if needed
        let finalBuffer: AVAudioPCMBuffer
        if streamFormat.sampleRate != targetFormat.sampleRate || streamFormat.channelCount != targetFormat.channelCount {
            guard let converter = AVAudioConverter(from: streamFormat, to: targetFormat) else { return }
            let ratio = targetFormat.sampleRate / streamFormat.sampleRate
            let convertedCapacity = AVAudioFrameCount(Double(pcmBuffer.frameLength) * ratio)
            guard convertedCapacity > 0 else { return }
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: convertedCapacity) else { return }
            var conversionError: NSError?
            var inputFramesLeft = pcmBuffer.frameLength
            converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
                if inputFramesLeft > 0 {
                    outStatus.pointee = .haveData
                    inputFramesLeft = 0
                    return pcmBuffer
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }
            if let conversionError = conversionError {
                print("[AudioStreamOutput] Format conversion error: \(conversionError.localizedDescription)")
                return
            }
            finalBuffer = convertedBuffer
        } else {
            finalBuffer = pcmBuffer
        }
        // Calculate RMS level for metering
        let level = AudioCaptureService.calculateRMS(for: finalBuffer)
        // Write to system audio file and update level on main thread
        Task { @MainActor in
            guard let systemFile = service.systemAudioFile else { return }
            do {
                try systemFile.write(from: finalBuffer)
            } catch {
                print("[AudioStreamOutput] System audio file write error: \(error.localizedDescription)")
                return
            }
            // Update system audio level for metering
            service.audioLevels.system = level
        }
    }
}

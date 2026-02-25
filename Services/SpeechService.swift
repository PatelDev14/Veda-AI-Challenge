import Foundation
import Speech
import AVFoundation
import Observation

@Observable
@MainActor
final class SpeechService {
    static let shared = SpeechService()

    // MARK: - Public State
    var transcribedText: String = ""
    var isRecording: Bool = false
    var permissionStatus: PermissionStatus = .notDetermined
    var errorMessage: String? = nil
    var onAutoStop: (() -> Void)? = nil

    enum PermissionStatus: Equatable {
        case notDetermined, authorized, denied, restricted
        var isAllowed: Bool { self == .authorized }
    }

    // MARK: - Private
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private var lastTranscriptionUpdate: Date = Date()
    private let silenceTimeout: TimeInterval = 2.0

    private init() {
        let preferred = SFSpeechRecognizer(locale: Locale.current)
        speechRecognizer = (preferred?.isAvailable == true)
            ? preferred
            : SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Permissions
    func requestPermissions() async {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        if speechStatus == .authorized && micGranted {
            permissionStatus = .authorized
        } else {
            permissionStatus = .denied
            errorMessage = "Permissions denied. Please enable microphone and speech in Settings."
        }
    }

    // MARK: - Start Recording
    func startRecording() throws {
        guard permissionStatus.isAllowed else { throw SpeechError.permissionDenied }

        tearDownEngine()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement,
                                     options: [.duckOthers, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        let recognizer = speechRecognizer
        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            // Callback fires on AVFoundation's internal queue.
            // Use DispatchQueue.main.async — NOT Task { @MainActor in }.
            // Task would try to "send" self across a concurrency boundary → crash.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let result {
                    self.transcribedText = result.bestTranscription.formattedString
                    self.lastTranscriptionUpdate = Date()
                    if result.isFinal {
                        self.stopRecording()
                    }
                }
                if let nsError = error as NSError? {
                    let silentCodes = [216, 1110, 203, 301]
                    if !silentCodes.contains(nsError.code) {
                        self.errorMessage = "Recognition error. Tap mic to retry."
                        print("❌ Speech \(nsError.code): \(nsError.localizedDescription)")
                    }
                    self.tearDownEngine()
                }
            }
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        let format = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
        transcribedText = ""
        lastTranscriptionUpdate = Date()
        startSilenceTimer()
    }

    // MARK: - Stop
    func stopRecording() {
        tearDownEngine()
        onAutoStop?()
    }

    // MARK: - Teardown
    private func tearDownEngine() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Silence Timer
    private func startSilenceTimer() {
        silenceTimer?.invalidate()

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isRecording else { return }
                let elapsed = Date().timeIntervalSince(self.lastTranscriptionUpdate)
                if elapsed > self.silenceTimeout, !self.transcribedText.isEmpty {
                    self.stopRecording()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        silenceTimer = timer
    }

    // MARK: - Reset
    func reset() {
        tearDownEngine()
        transcribedText = ""
        errorMessage = nil
    }
}

// MARK: - Errors
enum SpeechError: LocalizedError {
    case permissionDenied
    case recognizerUnavailable
    case audioEngineFailure

    var errorDescription: String? {
        switch self {
        case .permissionDenied:      return "Microphone or speech permission not granted."
        case .recognizerUnavailable: return "Speech recognizer is not available right now."
        case .audioEngineFailure:    return "Audio engine could not start."
        }
    }
}

//
//  VoiceFollow.swift
//  Cueflow (随读)
//
//  F3 spike: Apple speech recognition feeding the verified AlignmentEngine.
//  Tries on-device recognition first (low latency); falls back to server with
//  guidance if the on-device model isn't ready. Exposes char offsets so the UI
//  can highlight at word level, plus a live audio meter and auto-restart.
//

import Foundation
import Speech
import AVFoundation

// MARK: - Apple speech engine

final class AppleSpeechEngine {
    private let recognizer: SFSpeechRecognizer?
    private let requireOnDevice: Bool
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    var onText: ((String) -> Void)?
    var onEnded: ((Error?) -> Void)?
    var onLevel: ((Float) -> Void)?

    init(localeID: String, requireOnDevice: Bool) {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID))
        self.requireOnDevice = requireOnDevice
    }

    var isAvailable: Bool { recognizer?.isAvailable ?? false }
    var supportsOnDevice: Bool { recognizer?.supportsOnDeviceRecognition ?? false }
    var recognizerExists: Bool { recognizer != nil }

    static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }

    static func requestMicrophoneAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func start() throws {
        guard let recognizer else {
            throw NSError(domain: "Cueflow", code: 2, userInfo: [NSLocalizedDescriptionKey: "No recognizer for this language."])
        }
        task?.cancel()
        task = nil

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if requireOnDevice {
            guard recognizer.supportsOnDeviceRecognition else {
                throw NSError(domain: "Cueflow", code: 4,
                              userInfo: [NSLocalizedDescriptionKey: "On-device model unavailable for this language."])
            }
            req.requiresOnDeviceRecognition = true
        } else {
            req.requiresOnDeviceRecognition = false
        }
        request = req

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            throw NSError(domain: "Cueflow", code: 3, userInfo: [NSLocalizedDescriptionKey: "No microphone input (sample rate 0)."])
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            self?.reportLevel(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async { self?.onText?(text) }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async { self?.onEnded?(error) }
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
    }

    private func reportLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        var sum: Float = 0
        for i in 0..<n { let s = channel[i]; sum += s * s }
        let level = min(1, (sum / Float(n)).squareRoot() * 20)
        DispatchQueue.main.async { self.onLevel?(level) }
    }
}

// MARK: - Voice-follow orchestrator

@MainActor
final class VoiceFollowController: ObservableObject {
    static let shared = VoiceFollowController()

    @Published var isListening = false
    @Published var status: String = ""
    @Published var hint: String = ""
    @Published var recognizedText: String = ""
    @Published var audioLevel: Float = 0
    @Published private(set) var cursor: Int = 0
    @Published private(set) var onDevice = false
    /// Smoothed, slightly-anticipatory leading edge in character offsets, driven
    /// at ~60fps. Gives a flowing "follow" feel instead of discrete jumps.
    @Published var displayCharOffset: Double = 0

    private(set) var lines: [String] = []
    private var lineStartOffsets: [Int] = []
    private var scriptTokens: [ScriptToken] = []
    private var aligner: AlignmentEngine?
    private var engine: AppleSpeechEngine?
    private var whisperEngine: WhisperKitEngine?
    private var localeID = "zh-CN"
    private var restartCount = 0
    private var triedServer = false
    private var hasText = false

    // Smoothing / anticipation driver
    private var baseCharOffset: Double = 0      // recognition-confirmed leading edge
    private var lastBaseAdvance = Date()
    private var charRateEMA: Double = 0          // chars/sec, smoothed
    private var displayTask: Task<Void, Never>?
    private var displayRunning = false
    private var aggressiveLead = false   // larger anticipation to mask WhisperKit latency

    var lineCount: Int { lines.count }

    func lineStartOffset(_ i: Int) -> Int {
        (i >= 0 && i < lineStartOffsets.count) ? lineStartOffsets[i] : 0
    }

    var currentLineIndex: Int {
        guard !scriptTokens.isEmpty, !lineStartOffsets.isEmpty else { return 0 }
        let idx = min(max(cursor, 0), scriptTokens.count - 1)
        let offset = scriptTokens[idx].start
        var line = 0
        for (i, start) in lineStartOffsets.enumerated() {
            if start <= offset { line = i } else { break }
        }
        return line
    }

    /// Character offset up to which the script is considered "already read".
    var readUpToOffset: Int {
        guard cursor > 0, !scriptTokens.isEmpty else { return 0 }
        return scriptTokens[min(cursor, scriptTokens.count) - 1].end
    }

    /// Character range of the token currently being read (for highlight).
    var currentTokenRange: (Int, Int)? {
        guard cursor < scriptTokens.count else { return nil }
        let t = scriptTokens[cursor]
        return (t.start, t.end)
    }

    /// Line index for the smoothed leading edge (for auto-scroll).
    var displayLineIndex: Int {
        guard !lineStartOffsets.isEmpty else { return 0 }
        let off = Int(displayCharOffset.rounded())
        var line = 0
        for (i, start) in lineStartOffsets.enumerated() {
            if start <= off { line = i } else { break }
        }
        return line
    }

    func configure(scriptText: String) {
        // Collapse blank lines so paragraph gaps don't show big empty spaces while
        // following. Tokens, lines and offsets all derive from the same normalized
        // text, so alignment stays consistent. (The original script is untouched.)
        let normalized = Self.collapseBlankLines(scriptText)
        scriptTokens = ScriptTokenizer.tokenize(normalized)
        aligner = AlignmentEngine(script: scriptTokens.map(\.text))
        cursor = 0
        baseCharOffset = 0
        displayCharOffset = 0
        charRateEMA = 0
        lastBaseAdvance = Date()
        lines = normalized.components(separatedBy: "\n")
        var offsets: [Int] = []
        var acc = 0
        for (i, line) in lines.enumerated() {
            offsets.append(acc)
            acc += line.count + (i < lines.count - 1 ? 1 : 0)
        }
        lineStartOffsets = offsets
    }

    /// Drop blank / whitespace-only lines so multi-newline paragraph breaks don't
    /// create large empty gaps in the following view.
    static func collapseBlankLines(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Resolve the chosen engine against the script composition, then start.
    /// Keeps the common (Chinese/English-dominant) case on fast Apple recognition
    /// and only uses WhisperKit for genuinely heavy code-switching.
    func start(scriptText: String, engine: PrompterModel.VoiceEngine) async {
        let r = Self.resolve(engine, tokens: ScriptTokenizer.tokenize(scriptText))
        await start(scriptText: scriptText, localeID: r.locale, useWhisper: r.whisper)
    }

    static func resolve(_ engine: PrompterModel.VoiceEngine, tokens: [ScriptToken]) -> (locale: String, whisper: Bool) {
        switch engine {
        case .appleZh: return ("zh-CN", false)
        case .appleEn: return ("en-US", false)
        case .whisperMixed: return ("auto", true)
        case .auto:
            // Apple recognition in the dominant language is fast and follows well;
            // embedded other-language words are simply skipped by the fuzzy aligner.
            // (WhisperKit's follow isn't reliable yet, so auto stays on the fast path;
            //  pick "本地·中英混读" explicitly to try it.)
            let cjk = tokens.filter { $0.text.unicodeScalars.contains(where: ScriptTokenizer.isCJKScalar) }.count
            let latin = max(1, tokens.count) - cjk
            return cjk >= latin ? ("zh-CN", false) : ("en-US", false)
        }
    }

    func start(scriptText: String, localeID: String, useWhisper: Bool = false) async {
        self.localeID = localeID
        restartCount = 0
        triedServer = false
        hasText = false
        hint = ""
        status = "准备中…"
        configure(scriptText: scriptText)
        guard !scriptTokens.isEmpty else { status = L(.vfNoScript); return }

        status = "请求麦克风权限…"
        let micOK = await AppleSpeechEngine.requestMicrophoneAccess()
        guard micOK else { status = L(.vfPermissionDenied) + "  [mic:false]"; return }

        if !useWhisper {
            let speechOK = await AppleSpeechEngine.requestSpeechAuthorization()
            guard speechOK else { status = L(.vfPermissionDenied) + "  [speech:false]"; return }
        }

        displayRunning = true
        startDisplayLoop()

        if useWhisper {
            startWhisper()
        } else {
            status = "启动识别…"
            startEngine()
        }
    }

    private func startWhisper() {
        isListening = true
        onDevice = true
        aggressiveLead = true
        let hint = dominantLanguageHint
        let w = WhisperKitEngine()
        w.onStatus = { [weak self] s in self?.status = s }
        w.onText = { [weak self] t in self?.handleRecognized(t) }
        w.onLevel = { [weak self] l in self?.audioLevel = l }
        whisperEngine = w
        Task { await w.start(languageHint: hint) }
    }

    /// Steer Whisper by the script's dominant language (auto-detect tends to
    /// mis-pick "en" on Chinese scripts with embedded English terms). Counted by
    /// tokens (CJK = 1 char each, Latin = 1 word each) so word length doesn't skew it.
    private var dominantLanguageHint: String {
        let cjk = scriptTokens.filter { $0.text.unicodeScalars.contains(where: ScriptTokenizer.isCJKScalar) }.count
        return cjk >= (scriptTokens.count - cjk) ? "zh" : "en"
    }

    func stop() {
        isListening = false
        displayRunning = false
        displayTask?.cancel()
        displayTask = nil
        engine?.stop()
        engine = nil
        whisperEngine?.stop()
        whisperEngine = nil
        audioLevel = 0
        status = L(.vfReady)
    }

    private func startEngine() {
        aggressiveLead = false
        let requireOnDevice = !triedServer // try on-device first, then server
        let eng = AppleSpeechEngine(localeID: localeID, requireOnDevice: requireOnDevice)
        guard eng.recognizerExists else { status = L(.vfUnavailable) + " [recognizer=nil]"; return }

        eng.onText = { [weak self] text in self?.handleRecognized(text) }
        eng.onLevel = { [weak self] level in self?.audioLevel = level }
        eng.onEnded = { [weak self] err in self?.handleEnded(err) }

        do {
            try eng.start()
            engine = eng
            isListening = true
            hasText = false
            onDevice = requireOnDevice && eng.supportsOnDevice
            if onDevice {
                status = L(.vfListening) + " · " + L(.vfOnDevice)
                hint = ""
            } else {
                status = L(.vfListening) + " · 云端（延迟较高）"
                hint = L(.vfEnableDictationHint)
            }
        } catch {
            if requireOnDevice && !triedServer {
                triedServer = true       // on-device failed to start → use server
                startEngine()
            } else {
                isListening = false
                status = "启动失败：\(Self.describe(error))"
            }
        }
    }

    private func handleEnded(_ error: Error?) {
        guard isListening else { return }

        let old = engine
        old?.onText = nil
        old?.onEnded = nil
        old?.onLevel = nil
        old?.stop()
        engine = nil

        if let error {
            // On-device errored before producing any text → fall back to server.
            if onDevice && !triedServer && !hasText {
                triedServer = true
                status = "本机模型未就绪，改用云端…"
                startEngine()
                return
            }
            isListening = false
            audioLevel = 0
            status = "识别错误：\(Self.describe(error))"
            return
        }

        // Clean finalization (pause / ~1-min cap): restart to keep following.
        restartCount += 1
        guard restartCount < 60 else {
            isListening = false
            status = "识别已停止（多次重启）"
            return
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard isListening else { return }
            startEngine()
        }
    }

    private func handleRecognized(_ text: String) {
        recognizedText = text
        if !text.isEmpty { hasText = true; restartCount = 0 }
        guard let aligner else { return }
        let tokens = ScriptTokenizer.tokens(text)
        let newCursor = aligner.consume(recognizedTail: tokens)
        if newCursor != cursor { cursor = newCursor; updateBase() }
    }

    private func updateBase() {
        let count = scriptTokens.count
        let newBase = Double(cursor > 0 ? scriptTokens[min(cursor, count) - 1].end : 0)
        let now = Date()
        let dt = now.timeIntervalSince(lastBaseAdvance)
        if newBase > baseCharOffset, dt > 0.05 {
            let inst = (newBase - baseCharOffset) / dt
            charRateEMA = (charRateEMA == 0) ? inst : (charRateEMA * 0.7 + inst * 0.3)
        }
        lastBaseAdvance = now
        if newBase < displayCharOffset { displayCharOffset = newBase } // reread: snap edge back
        baseCharOffset = newBase
    }

    private func startDisplayLoop() {
        guard displayTask == nil else { return }
        displayTask = Task { @MainActor in
            var last = Date()
            while displayRunning && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                let now = Date()
                let dt = min(0.1, now.timeIntervalSince(last)); last = now
                // Anticipate slightly based on reading pace; decay during pauses.
                let sincePause = now.timeIntervalSince(lastBaseAdvance)
                let leadSeconds = aggressiveLead ? 0.75 : 0.4
                let leadCap = aggressiveLead ? 12.0 : 6.0
                let lead = sincePause < 0.85 ? min(leadCap, charRateEMA * leadSeconds) : 0
                let target = baseCharOffset + lead
                displayCharOffset += (target - displayCharOffset) * min(1.0, 10.0 * dt)
            }
        }
    }

    private static func describe(_ error: Error) -> String {
        let ns = error as NSError
        return "\(ns.domain) \(ns.code): \(ns.localizedDescription)"
    }
}

//
//  WhisperKitEngine.swift
//  Cueflow (随读)
//
//  Local, offline ASR via WhisperKit (Apple Silicon). Multilingual model →
//  supports Chinese-English mixed reading. Streams the mic through WhisperKit's
//  AudioStreamTranscriber and emits a growing transcript for the AlignmentEngine.
//  First use downloads a CoreML model (~tens–hundreds MB) from the model repo.
//

import Foundation
import WhisperKit

final class WhisperKitEngine {
    private var whisperKit: WhisperKit?
    private var transcriber: AudioStreamTranscriber?
    private var streamTask: Task<Void, Never>?

    /// Latest growing transcript (main queue).
    var onText: ((String) -> Void)?
    /// Input level 0...1 (main queue).
    var onLevel: ((Float) -> Void)?
    /// Human-readable status (main queue).
    var onStatus: ((String) -> Void)?

    /// Build a config that loads the bundled tiny model offline if present,
    /// otherwise falls back to downloading from the model hub.
    static func makeConfig() -> WhisperKitConfig {
        if let base = Bundle.main.resourceURL?.appendingPathComponent("WhisperBundle") {
            let modelDir = base.appendingPathComponent("openai_whisper-base")
            let tokDir = base.appendingPathComponent("tok")
            if FileManager.default.fileExists(atPath: modelDir.appendingPathComponent("config.json").path) {
                return WhisperKitConfig(model: "base", modelFolder: modelDir.path, tokenizerFolder: tokDir)
            }
        }
        return WhisperKitConfig(model: "base") // fallback: download
    }

    /// `languageHint` nil = auto-detect (best for mixed zh/en).
    func start(languageHint: String?) async {
        let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("WhisperBundle/openai_whisper-base/config.json")
        let isBundled = bundled.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        await MainActor.run {
            onStatus?(isBundled ? "加载本地语音模型…" : "下载语音模型（首次，请稍候）…")
        }
        do {
            let config = Self.makeConfig()
            let wk = try await WhisperKit(config)
            whisperKit = wk

            guard let tokenizer = wk.tokenizer else {
                await MainActor.run { onStatus?("模型未就绪（tokenizer 缺失）") }
                return
            }

            var options = DecodingOptions(task: .transcribe, language: languageHint)
            options.skipSpecialTokens = true

            let t = AudioStreamTranscriber(
                audioEncoder: wk.audioEncoder,
                featureExtractor: wk.featureExtractor,
                segmentSeeker: wk.segmentSeeker,
                textDecoder: wk.textDecoder,
                tokenizer: tokenizer,
                audioProcessor: wk.audioProcessor,
                decodingOptions: options,
                useVAD: false,   // some mics read as "silence" under VAD → never transcribes
                stateChangeCallback: { [weak self] _, newState in
                    let segText = (newState.confirmedSegments + newState.unconfirmedSegments)
                        .map(\.text)
                        .joined()
                    // Fall back to the in-progress decode so partials show live.
                    let text = segText.isEmpty ? newState.currentText : segText
                    let energy = newState.bufferEnergy.last ?? 0
                    DispatchQueue.main.async {
                        self?.onText?(text)
                        self?.onLevel?(min(1, energy * 5))
                    }
                }
            )
            transcriber = t

            await MainActor.run { onStatus?("聆听中…（WhisperKit 本地离线）") }

            streamTask = Task {
                do {
                    try await t.startStreamTranscription()
                } catch {
                    await MainActor.run { self.onStatus?("识别中断：\(error.localizedDescription)") }
                }
            }
        } catch {
            await MainActor.run { onStatus?("WhisperKit 启动失败：\(error.localizedDescription)") }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        let t = transcriber
        transcriber = nil
        whisperKit = nil
        Task { await t?.stopStreamTranscription() }
    }
}

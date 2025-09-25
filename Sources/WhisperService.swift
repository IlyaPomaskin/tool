import Foundation
import AVFoundation

class WhisperService: @unchecked Sendable {
    private var whisperContext: WhisperContext?
    
    init(modelFileName: String = "ggml-large-v3") {
        let currentDir = FileManager.default.currentDirectoryPath
        let fullModelPath = URL(fileURLWithPath: currentDir)
            .appendingPathComponent("models")
            .appendingPathComponent(modelFileName).path
        
        // Check if model file exists
        guard FileManager.default.fileExists(atPath: fullModelPath) else {
            print("❌ Model file not found at: \(fullModelPath)")
            return
        }

        do {
            whisperContext = try WhisperContext.createContext(path: fullModelPath)
            print("✅ Whisper context initialized with model: \(fullModelPath)")
        } catch {
            print("❌ Failed to initialize Whisper context: \(error.localizedDescription)")
        }
    }

    // Main transcription method
    func transcribe(from fileURL: URL, translate: Bool) async -> String {
        let samples = try! await convertAudioToSamples(fileURL: fileURL)
        await whisperContext!.fullTranscribe(samples: samples, language: "ru", translate: translate)
        let transcription = await whisperContext!.getTranscription()
        
        print("✅ Local transcription completed: \(transcription)")
        return transcription
    }

    // Convert WAV audio file to Float samples for Whisper
    // Since audio is already recorded at 16kHz mono, conversion is simplified
    private func convertAudioToSamples(fileURL: URL) async throws -> [Float] {
        let asset = AVAsset(url: fileURL)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let assetTrack = tracks.first!
        
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        let assetReader = try AVAssetReader(asset: asset)
        let assetReaderOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: outputSettings)
        
        assetReader.add(assetReaderOutput)
        assetReader.startReading()
        
        var samples: [Float] = []
        
        while assetReader.status == .reading {
            if let sampleBuffer = assetReaderOutput.copyNextSampleBuffer(),
               let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                let length = CMBlockBufferGetDataLength(blockBuffer)
                let audioData = UnsafeMutablePointer<Float>.allocate(capacity: length / MemoryLayout<Float>.size)
                defer { audioData.deallocate() }
                
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: audioData)
                
                let sampleCount = length / MemoryLayout<Float>.size
                samples.append(contentsOf: UnsafeBufferPointer(start: audioData, count: sampleCount))
                
                CMSampleBufferInvalidate(sampleBuffer)
            }
        }
        
        print("✅ Audio conversion completed: \(samples.count) samples at 16kHz")
        return samples
    }
}

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
        guard let context = whisperContext else {
            print("❌ Whisper context not initialized")
            return ""
        }

        do {
            // Convert audio file to float samples
            let samples = try await convertAudioToSamples(fileURL: fileURL)
            
            // Perform transcription with Russian language
            await context.fullTranscribe(samples: samples, language: "ru", translate: translate)
            
            // Get transcription result
            let transcription = await context.getTranscription()
            
            print("✅ Local transcription completed: \(transcription)")
            return transcription

        } catch {
            print("❌ Error transcribing audio: \(error.localizedDescription)")
            return ""
        }
    }

    // Convert WAV audio file to Float samples for Whisper
    // Since audio is already recorded at 16kHz mono, conversion is simplified
    private func convertAudioToSamples(fileURL: URL) async throws -> [Float] {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let asset = AVAsset(url: fileURL)
                    
                    let tracks = try await asset.loadTracks(withMediaType: .audio)
                    guard let assetTrack = tracks.first else {
                        continuation.resume(throwing: NSError(domain: "WhisperService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No audio track found"]))
                        return
                    }
                    
                    // Since input is already 16kHz mono PCM, we just need to convert to float
                    let outputSettings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: 16000,
                        AVNumberOfChannelsKey: 1,
                        AVLinearPCMBitDepthKey: 32,
                        AVLinearPCMIsFloatKey: true,
                        AVLinearPCMIsBigEndianKey: false
                    ]
                    
                    guard let assetReader = try? AVAssetReader(asset: asset) else {
                        continuation.resume(throwing: NSError(domain: "WhisperService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create asset reader"]))
                        return
                    }
                    
                    let assetReaderOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: outputSettings)
                    
                    assetReader.add(assetReaderOutput)
                    assetReader.startReading()
                    
                    var samples: [Float] = []
                    
                    while assetReader.status == .reading {
                        if let sampleBuffer = assetReaderOutput.copyNextSampleBuffer() {
                            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                                let length = CMBlockBufferGetDataLength(blockBuffer)
                                let audioData = UnsafeMutablePointer<Float>.allocate(capacity: length / MemoryLayout<Float>.size)
                                defer { audioData.deallocate() }
                                
                                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: audioData)
                                
                                let sampleCount = length / MemoryLayout<Float>.size
                                for i in 0..<sampleCount {
                                    samples.append(audioData[i])
                                }
                            }
                            CMSampleBufferInvalidate(sampleBuffer)
                        }
                    }
                    
                    if assetReader.status == .completed {
                        print("✅ Audio conversion completed: \(samples.count) samples at 16kHz")
                        continuation.resume(returning: samples)
                    } else {
                        continuation.resume(throwing: NSError(domain: "WhisperService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Audio reading failed: \(assetReader.error?.localizedDescription ?? "Unknown error")"]))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

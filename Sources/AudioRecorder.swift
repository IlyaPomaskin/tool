import Foundation
import AVFoundation

class AudioRecorder: NSObject, @unchecked Sendable {
    private var isInitialized = false
    private var isInitializing = false
    
    
    override init() {
        super.init()
    }
    
    private func ensureAudioInitialized() async -> Bool {
        if isInitialized {
            return true
        }
        
        if isInitializing {
            // Wait for initialization to complete
            while isInitializing {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            return isInitialized
        }
        
        isInitializing = true
        
        // Request microphone access permission
        let granted = await requestMicrophoneAccess()
        
        if granted {
            isInitialized = true
        } else {
            print("Microphone access not granted")
        }
        
        isInitializing = false
        return isInitialized
    }
    
    private func requestMicrophoneAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    var audioRecorder: AVAudioRecorder?

    func startRecording() {
        do {
            let tempURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("temp_recording.wav")

            // Settings optimized for whisper.cpp: 16kHz, mono, 16-bit PCM
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16000.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]

            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()

            print("Recording started: \(tempURL)")
        } catch {
            print("Recording error: \(error)")
        }
    }

     func stopRecording() -> URL {
        audioRecorder?.stop()
        let tempURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("temp_recording.wav")
        print("Recording stopped")
        return tempURL
    }
}


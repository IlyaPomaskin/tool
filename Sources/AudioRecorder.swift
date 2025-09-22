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
            // Ждем завершения инициализации
            while isInitializing {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
            return isInitialized
        }
        
        isInitializing = true
        
        // Запрашиваем разрешение на доступ к микрофону
        let granted = await requestMicrophoneAccess()
        
        if granted {
            isInitialized = true
        } else {
            print("Доступ к микрофону не разрешен")
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
                .appendingPathComponent("temp_recording.m4a")

            // let settings: [String: Any] = [
            //     AVFormatIDKey: kAudioFormatLinearPCM,
            //     AVSampleRateKey: 16000,
            //     AVNumberOfChannelsKey: 1,
            //     AVLinearPCMBitDepthKey: 16,
            //     AVLinearPCMIsFloatKey: false,
            //     AVLinearPCMIsBigEndianKey: false
            // ]

            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: 128000,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]

            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()

            print("Запись началась: \(tempURL)")}
        catch {
            print("Ошибка записи: \(error)")
        }
    }

     func stopRecording() -> URL {
        audioRecorder?.stop()
        let tempURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("temp_recording.m4a")
        print("Запись остановлена")
        return tempURL
    }
}


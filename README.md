# Tool

## 🚀 Features

- **Global hotkeys** for voice recording
- **Local Whisper transcription** with fallback to OpenAI
- **Multi-language support**
- **Screenshot OCR**
- **Offline processing** using local Whisper models

## ⚙️ Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd mic-gpt
```

2. Set up Whisper models:
```bash
# Create models directory
mkdir models

# Download Whisper models (choose one or more):
# Recommended base or small models for best performance
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin" -o models/ggml-base.bin
# OR for smaller size:
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin" -o models/ggml-small.bin
```

3. (Optional) Set up OpenAI API key for fallback:
```bash
export OPENAI_API_KEY="your-api-key-here"
```

4. Build the project:
```bash
swift build
```

5. Run the application:
```bash
swift run
```

## 🎯 Usage

### Audio Transcription
1. Press and hold `Control + Option + Command + M` to start recording
2. Speak into the microphone
3. Release hotkey to stop
4. Audio is processed locally with Whisper (falls back to OpenAI if needed)
5. Transcription result is displayed in the interface

### Screenshot OCR
1. Press `Control + Option + Command + B` for screenshot OCR
2. Select area on screen
3. Text is extracted and copied to clipboard

## 🔧 Configuration

### Whisper Models
- The app automatically uses the first `.bin` model found in the `models/` directory
- Recommended models for different use cases:
  - `ggml-base.bin` (~140MB) - good balance of speed/quality
  - `ggml-small.bin` (~460MB) - better quality
  - `ggml-tiny.bin` (~39MB) - fastest, lower quality

### OpenAI API (Fallback)
1. Get API key from [platform.openai.com](https://platform.openai.com)
2. Set environment variable:
```bash
export OPENAI_API_KEY="sk-..."
```
3. Used automatically if local Whisper fails

### Permissions
On first launch, macOS will request permissions:
- **Microphone access** - for voice recording
- **Accessibility features** - for global hotkeys

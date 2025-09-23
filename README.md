# Tool - Voice Assistant

## 🚀 Features

- **Global hotkeys** for voice recording
- **Automatic transcription** via OpenAI Whisper
- **Russian language support**
- **Screenshot OCR**

## ⚙️ Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd mic-gpt
```

2. Set up OpenAI API key:
```bash
export OPENAI_API_KEY="your-api-key-here"
```

3. Build the project:
```bash
swift build
```

4. Run the application:
```bash
swift run
```

## 🎯 Usage

### Workflow
1. Press and hold `Control + Option + Command + M` to start recording
2. Speak into the microphone
3. Release hotkey to stop
4. Audio is automatically sent to OpenAI
5. Transcription result is displayed in the interface
  
1. `Control + Option + Command + B` for screenshot OCR

## 🔧 Configuration

### OpenAI API
1. Get API key from [platform.openai.com](https://platform.openai.com)
2. Set environment variable:
```bash
export OPENAI_API_KEY="sk-..."
```

### Permissions
On first launch, macOS will request permissions:
- **Microphone access** - for voice recording
- **Accessibility features** - for global hotkeys

# IVEX - Premium Hairstyle App UI Prototype

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Appwrite-FD366E?style=for-the-badge&logo=appwrite&logoColor=white" />
  <img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/Gemini-8E75B2?style=for-the-badge&logo=google&logoColor=white" />
</p>

IVEX is a premium Flutter app prototype focused on clean, branded UX for hairstyle consultation.
The current build ships a polished splash, custom logo, full login/signup flow, and a professional app shell.
Backend API calls are intentionally paused in this iteration.

## ✨ Features

- **Professional Splash Screen** - animated premium entry experience
- **Custom IVEX Logo** - vector logo rendered directly in Flutter
- **Full Auth UX** - complete sign in and sign up with validation
- **Modern App Shell** - discover, studio, and profile tabs with polished UI

## 🏗️ Architecture (Current Build)

```
Flutter App → Splash → Auth (local state) → App Shell (UI-first)
```

## 📁 Project Structure

```
ivex/
├── lib/
│   ├── config/appwrite_config.dart    # Appwrite configuration
│   ├── models/analysis_result.dart    # Data models
│   ├── services/appwrite_service.dart # API services
│   ├── screens/
│   │   ├── home_screen.dart           # Upload interface
│   │   └── result_screen.dart         # Results display
│   └── main.dart                      # App entry point
├── functions/
│   └── analyze-hairstyle/
│       ├── main.py                    # AI processing function
│       └── requirements.txt           # Python dependencies
└── APPWRITE_SETUP.md                  # Backend setup guide
```

## 🚀 Quick Start

### 1. Configure Appwrite
Follow [APPWRITE_SETUP.md](./APPWRITE_SETUP.md) to set up backend services.

### 2. Update Configuration
Edit `lib/config/appwrite_config.dart` with your Appwrite Project ID.

### 3. Run the App
```bash
flutter pub get
flutter run
```

## 🔑 API Keys Required

No external API keys are required for the current UI-only prototype.

<!-- Original backend table kept for future re-activation. -->

| Service | Purpose | Get Key |
|---------|---------|---------|
| Appwrite | Backend/Database | [cloud.appwrite.io](https://cloud.appwrite.io) |
| Gemini | Face Analysis | [aistudio.google.com](https://aistudio.google.com/apikey) |
| Replicate | Image Generation | [replicate.com](https://replicate.com/account/api-tokens) |

## 🎨 Design System

- **Background**: #1A1F2C (Deep Charcoal)
- **Accent**: #00D2FF (Electric Cyan)
- **Font**: Montserrat
- **Logo**: Triangle icon ▲

## 📄 License

MIT License

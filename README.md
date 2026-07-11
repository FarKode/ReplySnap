# Reply Snap ⚡

[![Flutter Version](https://img.shields.io/badge/Flutter-v3.10+-02569B?logo=flutter&style=flat-square)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&style=flat-square)](https://android.com)
[![Privacy Policy](https://img.shields.io/badge/Privacy-100%25%20Offline-green?style=flat-square)](https://farkode.github.io/ReplySnap/privacy-policy.html)
[![Developer](https://img.shields.io/badge/Developer-FarKode-purple?style=flat-square)](https://github.com/FarKode)

An offline-first, zero-server-cost mobile application designed to scan chat screenshots using on-device OCR and generate context-appropriate smart replies instantly. 

Designed with a premium neomorphic glassmorphic dark theme and micro-interactions.

---

## ✨ Features

- **📸 Instant OCR Scan (Google ML Kit):** Extract conversation threads from WhatsApp, Messenger, Telegram, or SMS screenshots in milliseconds — completely offline.
- **⚡ Smart Combination Engine:** Automatically generates 3 unique, context-aware reply suggestions.
- **🌐 Multilingual Support:** Supports 8+ languages including English, Bengali (বাংলা), Banglish, Hindi (हिंदी), Hinglish, Tamil, and Telugu.
- **🎭 Contextual Tone Switcher:** Generate replies in 4 distinct styles: **Polite, Funny, Direct, or Formal**.
- **🔒 Advanced Privacy Shield:** Scans and redacts emails, phone numbers, and OTPs locally *before* generating replies. No personal data ever touches the cloud.
- **💾 Local Cache & History:** Save favorite replies and view generation history locally using Hive NoSQL storage.
- **📺 Smart Monetization:** Built-in Google AdMob integration supporting banner ads and non-intrusive rewarded ads to unlock unlimited generations.

---

## 🏗️ Architecture & Technology Stack

```
   ┌────────────────────────────────────────────────────────┐
   │                       ReplySnap                        │
   │  ┌────────────────┐  ┌────────────────┐  ┌──────────┐  │
   │  │   OCR (ML Kit) │  │ Privacy Shield │  │ Hive DB  │  │
   │  └───────┬────────┘  └───────┬────────┘  └────┬─────┘  │
   │          └───────────────────┼────────────────┘        │
   │                              ▼                         │
   │                        State (Riverpod)                │
   │                              ▼                         │
   │                        Neomorphic UI                   │
   └────────────────────────────────────────────────────────┘
```

- **Core Framework:** Flutter (Dart)
- **State Management:** Riverpod (StateNotifier)
- **Database:** Hive (Local NoSQL Database)
- **AI/ML Engine:** Google ML Kit (On-Device Text Recognition)
- **Ads Integration:** Google Mobile Ads (AdMob)
- **Analytics:** Firebase Analytics
- **Build System:** Gradle Kotlin DSL (.kts) with R8/Proguard code hardening

---

## 🛠️ Installation & Setup

### Prerequisites
- Flutter SDK (v3.10.0 or higher)
- Android SDK (v33+ compiler)
- Java Development Kit (JDK 17)

### Step-by-Step Run
1. **Clone the repository:**
   ```bash
   git clone https://github.com/FarKode/ReplySnap.git
   cd ReplySnap
   ```

2. **Get dependencies:**
   ```bash
   flutter pub get
   ```

3. **Provide Firebase Configurations:**
   Place your production `google-services.json` file inside the `android/app/` folder.

4. **Verify Signing Configs:**
   Create a `key.properties` file in the `android/` directory:
   ```properties
   storePassword=your_keystore_password
   keyPassword=your_key_password
   keyAlias=your_key_alias
   storeFile=../../upload-keystore.jks
   ```

5. **Run the application:**
   ```bash
   flutter run --release
   ```

---

## 🔐 Security & Obfuscation Configuration

The production build is fully secured against reverse engineering using Google R8 minification. The configuration inside `android/app/proguard-rules.pro` includes rules to optimize and protect ML Kit and WorkManager database classes:

```proguard
# Prevent R8 compilation warnings on unused ML Kit optional languages
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Protect WorkManager and Room database internals
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.room.**
-dontwarn androidx.work.**
```

---

## 📄 Privacy Policy

We take user privacy extremely seriously. Read our official and fully compliant [Privacy Policy](https://farkode.github.io/ReplySnap/privacy-policy.html).

---

## 👥 Contributors & Brand

- Developed and maintained by **[FarKode](https://github.com/FarKode)**.
- Brand assets and design rights reserved &copy; 2026.

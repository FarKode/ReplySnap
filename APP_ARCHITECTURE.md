# Reply Snap — Complete Architecture & Feature Documentation

> **App Name:** Reply Snap  
> **Package:** `com.farkode.replysnap`  
> **Developer:** FarKode  
> **Version:** 1.0.0+1  
> **Framework:** Flutter (Dart)  
> **Min Android SDK:** Flutter default (~21)  
> **Target SDK / Compile SDK:** 37  
> **Build System:** Gradle Kotlin DSL (.kts)

---

## 📁 Project File Structure

```
ReplySnapApp/
├── lib/
│   ├── main.dart              # App entry point, initialization, sharing intent
│   ├── logic.dart             # Business logic, state, OCR, templates, privacy
│   ├── screens.dart           # All UI screens, AdMob widgets, navigation
│   └── theme.dart             # Neomorphic design system, colors, buttons
├── android/
│   ├── app/
│   │   ├── build.gradle.kts   # App-level Gradle config (Kotlin DSL)
│   │   ├── google-services.json  # Firebase configuration
│   │   ├── proguard-rules.pro    # R8/Obfuscation security rules
│   │   └── src/main/
│   │       ├── AndroidManifest.xml  # Permissions, AdMob ID, intent filters
│   │       └── kotlin/com/farkode/replysnap/
│   │           └── MainActivity.kt
│   ├── build.gradle.kts       # Root-level Gradle config
│   └── settings.gradle.kts    # Plugin management (Google Services, etc.)
├── assets/
│   └── app_icon.jpeg          # Launcher icon source
├── test/
│   └── logic_test.dart        # Automated self-check tests
├── pubspec.yaml               # Dependencies & metadata
├── keystore_info.txt          # Release keystore credentials (SHA-1, SHA-256)
├── upload-keystore.jks        # Release signing keystore
├── upload-certificate.pem     # Play Console verification certificate
├── FarKode_ReplySnap_Keystore.zip  # Backup bundle of all key files
└── play_store_listing.md      # SEO-optimized Play Store listing
```

---

## 🏗️ System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        main.dart                             │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ MobileAds    │  │ Firebase     │  │ HistoryService    │  │
│  │ .initialize()│  │ .initializeApp│ │ .init() (Hive)    │  │
│  └──────┬───────┘  └──────┬───────┘  └───────┬───────────┘  │
│         │                 │                  │               │
│         └─────────┬───────┘──────────────────┘               │
│                   ▼                                          │
│         ProviderScope(child: ReplySnapApp)                   │
│                   │                                          │
│     ReceiveSharingIntent (Image Share Listener)              │
└──────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────────┐
│                      screens.dart                            │
│                                                              │
│  AppLauncher ──▶ SplashScreen ──▶ OnboardingScreen           │
│                                        │                     │
│                                        ▼                     │
│                                   HomeScreen                 │
│                                   │        │                 │
│                            ┌──────┘        └──────┐          │
│                            ▼                      ▼          │
│                    OcrPreviewScreen        SettingsScreen     │
│                            │                                 │
│                            ▼                                 │
│                      ResultScreen                            │
│                                                              │
│  Widgets: NeomorphicAdBanner, AdManager                      │
└──────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────────┐
│                       logic.dart                             │
│                                                              │
│  ┌─────────────────┐  ┌────────────────┐  ┌──────────────┐  │
│  │  ReplyNotifier   │  │ TemplateEngine │  │ PrivacyService│ │
│  │  (StateNotifier) │  │ (Combination   │  │ (PII Redact) │  │
│  │                  │  │  Generator)    │  │              │  │
│  │  - processImage()│  │  - _openings   │  │  - Email     │  │
│  │  - detectIntent()│  │  - _bodies     │  │  - Phone(BD) │  │
│  │  - generateReplies│ │  - _closings   │  │  - Phone(IN) │  │
│  │  - updateTone()  │  │  - _emojis     │  │  - OTP/PIN   │  │
│  │  - updateLanguage│  │                │  │              │  │
│  └─────────────────┘  └────────────────┘  └──────────────┘  │
│                                                              │
│  ┌─────────────────┐                                         │
│  │ HistoryService   │  (Hive NoSQL Local DB)                 │
│  │  - getHistory()  │  - generation_count                    │
│  │  - addHistoryItem│  - regenerate_count                    │
│  │  - getFavorites() │  - favorites                          │
│  │  - toggleFavorite│  - first_launch                        │
│  └─────────────────┘                                         │
└──────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────────┐
│                       theme.dart                             │
│                                                              │
│  AppTheme                         NeomorphicButton           │
│  - background: #E3EDF7            - Extruded state (raised)  │
│  - accent: #8B5CF6 (Violet)       - Pressed state (inset)   │
│  - text: #31394A (Slate)          - Selected state (border)  │
│  - neomorphicCard()               - AnimatedContainer (100ms)│
│  - neomorphicReadable()                                      │
└──────────────────────────────────────────────────────────────┘
```

---

## 🔧 Dependencies & Their Roles

| Package | Version | Purpose |
|:---|:---|:---|
| `flutter_riverpod` | ^2.5.1 | State Management (StateNotifierProvider) |
| `google_mlkit_text_recognition` | ^0.13.0 | On-device OCR — reads text from screenshots |
| `hive_flutter` | ^1.1.0 | Offline NoSQL database — history, favorites, counters |
| `image_picker` | ^1.1.2 | Camera & gallery image selection |
| `receive_sharing_intent` | ^1.7.0 | Receives shared screenshots from other apps |
| `share_plus` | ^10.0.0 | Shares generated replies to other apps |
| `google_mobile_ads` | ^9.0.0 | AdMob Banner + Rewarded Video Ads |
| `firebase_core` | ^4.11.0 | Firebase initialization |
| `firebase_analytics` | ^12.4.3 | Firebase Analytics event tracking |

### Dev Dependencies

| Package | Version | Purpose |
|:---|:---|:---|
| `flutter_test` | SDK | Unit testing framework |
| `flutter_lints` | ^3.0.0 | Code quality & lint rules |
| `flutter_launcher_icons` | ^0.13.1 | Automated app icon generation |

---

## 📱 Screen Flow & Navigation

```
App Launch
    │
    ▼
[SplashScreen] ── Animated logo + fade (2 seconds)
    │
    ├── First Launch? ──▶ [OnboardingScreen] ── Language selection
    │                            │
    │                            ▼
    └── Returning User ──▶ [HomeScreen]
                              │
                    ┌─────────┼──────────┐
                    │         │          │
                    ▼         ▼          ▼
              [Camera/     [Paste    [Settings
               Gallery]     Text]     Screen]
                    │         │
                    └────┬────┘
                         ▼
                  [OcrPreviewScreen]
                   - Shows extracted text
                   - Edit text manually
                   - Select tone & language
                   - "Generate Replies" button
                   - ⚠️ 3-generation ad limit check
                         │
                         ▼
                   [ResultScreen]
                   - Shows 3 reply cards
                   - Copy / Share / Favorite
                   - "Regenerate" button
                   - ⚠️ 3-regeneration ad limit check
```

---

## ⚙️ Core Engine: How Reply Generation Works

### Step 1: Screenshot OCR (Google ML Kit)
```
User takes screenshot → Opens in ReplySnap (via share or camera)
        │
        ▼
Google ML Kit TextRecognizer.processImage()
        │
        ▼
Raw text extracted from image (100% on-device, offline)
```

### Step 2: Privacy Redaction (PrivacyService)
```
Raw Text → PrivacyService.redact()
        │
        ├── Email addresses    → [EMAIL REDACTED]
        ├── BD phone numbers   → [PHONE REDACTED]  (01X-XXXXXXXX)
        ├── IN phone numbers   → [PHONE REDACTED]  (+91 XXXXXXXXXX)
        └── OTP/PIN codes      → [OTP REDACTED]    (4-6 digit codes)
```

### Step 3: Intent Detection (Keyword Matching)
```
Redacted Text → detectIntent()
        │
        ▼
Scans for keywords in 11 categories:
        │
        ├── greeting      → "hello", "hi", "kemon", "namaste"
        ├── request       → "help", "please", "deben"
        ├── invitation    → "party", "birthday", "wedding", "dawat"
        ├── apology       → "sorry", "maaf", "bhul"
        ├── complaint     → "problem", "issue", "kharaap"
        ├── paymentReminder → "payment", "bkash", "taka", "bill"
        ├── work          → "office", "meeting", "deadline"
        ├── customerQuery → "price", "order", "available"
        ├── boundary      → "call korben na", "disturb"
        ├── appreciation  → "thank", "dhonnobad", "great"
        └── general       → (fallback if no match)
```

### Step 4: Dynamic Combination (TemplateEngine)
```
Intent + Tone + Language → TemplateEngine.generate()
        │
        ├── Pick random Opening  (e.g., "Thank you.")
        ├── Pick indexed Body    (e.g., "I'll try my best to attend.")
        ├── Pick random Closing  (e.g., "See you there!")
        └── Pick random Emoji    (e.g., "😊")
        │
        ▼
Combined: "Thank you. I'll try my best to attend. See you there! 😊"
        │
        ▼
Returns 3 unique combinations (deduped via .toSet())
```

### Supported Languages × Tones Matrix

| Language | Polite | Friendly | Formal | Direct | Funny | Polite No |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| English | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Bengali (বাংলা) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Banglish | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Hindi (हिंदी) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Hinglish | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Tamil (தமிழ்) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Telugu (తెలుగు) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**Total Template Combinations:** 7 languages × 6 tones × 11 intents × 3 parts = **~1,386 unique template parts**

---

## 💰 Monetization Architecture

### Banner Ad (Home Screen)
```
NeomorphicAdBanner widget (StatefulWidget)
    │
    ├── Loads: ca-app-pub-5125220264235408/7660350782
    ├── Position: Bottom of HomeScreen
    ├── Fallback: SizedBox.shrink() (invisible if ad fails)
    └── Frame: Neomorphic card with soft shadows
```

### Rewarded Video Ad (Generation & Regeneration Limits)
```
AdManager (static singleton)
    │
    ├── Preloads at app startup: AdManager.loadRewardedAd()
    ├── Ad Unit: ca-app-pub-5125220264235408/5991633209
    │
    ├── Trigger 1: Generate Replies (OcrPreviewScreen)
    │   └── Counter: HistoryService.getGenerationCount()
    │       ├── Count < 3  → Generate freely
    │       └── Count >= 3 → Show neomorphic dialog → Watch ad → Reset to 0
    │
    ├── Trigger 2: Regenerate Options (ResultScreen)
    │   └── Counter: HistoryService.getRegenerateCount()
    │       ├── Count < 3  → Regenerate freely
    │       └── Count >= 3 → Show neomorphic dialog → Watch ad → Reset to 0
    │
    └── Offline Fallback: If ad fails to load → Allow action anyway
```

### Revenue Flow
```
User installs (free) → Uses 3 free generations → Watches video ad
    → Gets 3 more free generations → Watches another video ad → Loop

Banner ad impression revenue runs continuously on HomeScreen
```

---

## 🔒 Security Architecture

### R8/Proguard Obfuscation
```
proguard-rules.pro
    │
    ├── ML Kit optional languages: -dontwarn (Chinese, Japanese, Korean, Devanagari)
    ├── WorkManager: -keep class androidx.work.**
    └── Room Database: -keep class androidx.room.**
```

### Privacy Protection
- **Zero network transmission** of user data (fully offline processing)
- **PII redaction** before storing in history (emails, phones, OTPs)
- **No Accessibility permission** required
- **No contacts/SMS/call log** access
- **Hive encrypted local storage** only

### Release Signing
```
upload-keystore.jks
    ├── Alias: upload
    ├── Validity: 10,000 days
    ├── Algorithm: RSA 2048-bit
    ├── SHA-1: (in keystore_info.txt)
    └── SHA-256: (in keystore_info.txt)
```

---

## 🗄️ Local Database Schema (Hive)

| Key | Type | Purpose |
|:---|:---|:---|
| `first_launch` | `bool` | Show onboarding only once |
| `history` | `List<Map>` | Last 20 generated reply sessions |
| `favorites` | `List<String>` | User-saved favorite replies |
| `generation_count` | `int` | Tracks generate actions (resets after ad) |
| `regenerate_count` | `int` | Tracks regenerate actions (resets after ad) |

### History Item Schema
```json
{
  "original": "Truncated input text (max 100 chars)...",
  "replies": ["Reply 1", "Reply 2", "Reply 3"],
  "intent": "invitation",
  "tone": "Polite",
  "language": "Bengali",
  "timestamp": "2026-07-11T17:30:00.000Z"
}
```

---

## 🎨 Design System (Neomorphic UI)

### Color Palette
| Token | Hex | Usage |
|:---|:---|:---|
| `background` | `#E3EDF7` | Scaffold & card base |
| `surface` | `#E3EDF7` | Seamless 3D mold |
| `accent` | `#8B5CF6` | Buttons, highlights (Vibrant Violet) |
| `text` | `#31394A` | Primary text (Deep Slate) |
| `textMuted` | `#7A869A` | Secondary text (Muted Grey) |
| Shadow Dark | `#A3B1C6` | Bottom-right shadow |
| Shadow Light | `#FFFFFF` | Top-left highlight |

### Neomorphic Card States
| State | Shadow Direction | Effect |
|:---|:---|:---|
| **Extruded (default)** | Dark ↘ + Light ↖ | Raised 3D button |
| **Pressed/Selected** | Inverted shadows | Debossed/inset feel |
| **Readable (inset)** | Subtle dark ↘ only | Text input areas |

### Animation
- Button press: `AnimatedContainer` with `100ms` duration
- Splash screen: `FadeTransition` with `AnimationController`
- Screen transitions: `MaterialPageRoute` (default slide)

---

## 🔗 Android Manifest Configuration

```xml
<!-- Permissions -->
<uses-permission android:name="android.permission.INTERNET"/>

<!-- Intent Filters -->
- MAIN / LAUNCHER (app icon tap)
- SEND / image/* (share screenshot from any app)

<!-- Metadata -->
- flutterEmbedding: 2
- AdMob App ID: ca-app-pub-5125220264235408~5703858599
```

---

## 🧪 Testing

### Automated Tests
```bash
flutter test test/logic_test.dart
```
- Validates TemplateEngine output for all language/tone/intent combinations
- Ensures PrivacyService correctly redacts PII
- Verifies HistoryService CRUD operations

### Manual Verification Checklist
- [ ] App launches without crash (release mode)
- [ ] Screenshot OCR extracts text correctly
- [ ] All 7 languages generate replies
- [ ] All 6 tones produce different outputs
- [ ] 4th generation triggers video ad dialog
- [ ] 4th regeneration triggers video ad dialog
- [ ] Banner ad displays on HomeScreen
- [ ] Offline mode works without errors
- [ ] Share/Copy buttons work correctly
- [ ] History saves and displays properly
- [ ] Favorites toggle works

---

## 📊 Build Configuration Summary

| Parameter | Value |
|:---|:---|
| **Application ID** | `com.farkode.replysnap` |
| **Compile SDK** | 37 |
| **Target SDK** | 37 |
| **Java Version** | 17 |
| **Kotlin JVM Target** | 17 |
| **Gradle Plugin** | Android 9.0.1 |
| **Kotlin Version** | 2.3.20 |
| **Google Services Plugin** | 4.4.2 |
| **R8 Minification** | Enabled |
| **Proguard** | Custom rules applied |
| **Release APK Size** | ~82.6 MB |

---

*Last Updated: July 11, 2026*  
*Document maintained by FarKode Development Team*

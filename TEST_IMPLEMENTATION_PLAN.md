# Reply Snap — Test Implementation Plan

---

## Phase 1: Codebase & Documentation Comprehension

### Architecture Summary

| Layer | File | Responsibility |
|:---|:---|:---|
| Entry & Init | `main.dart` | MobileAds, Firebase, Hive init; sharing intent listener |
| State & Logic | `logic.dart` | ReplyNotifier (Riverpod), PrivacyService, HistoryService, TemplateEngine |
| Presentation | `screens.dart` | 8 screens/widgets, AdManager, NeomorphicAdBanner |
| Design System | `theme.dart` | AppTheme colors, neomorphicCard(), NeomorphicButton |

### Critical Data Flows

```
Image/Text Input → OCR (ML Kit) → PrivacyService.redact()
    → ReplyNotifier.detectIntent() → TemplateEngine.generate()
    → ReplyState.generatedReplies → UI ResultScreen
    → HistoryService.addHistoryItem() (Hive persistence)
```

### Technology Stack
- **Framework:** Flutter/Dart
- **State:** Riverpod (StateNotifierProvider)
- **OCR:** Google ML Kit (on-device)
- **Database:** Hive (NoSQL, local)
- **Ads:** Google Mobile Ads (Banner + Rewarded)
- **Analytics:** Firebase Analytics
- **Build:** Gradle Kotlin DSL, R8/Proguard

---

## Phase 2: Strategic Test Plan

---

### 1. Core Testing Phases

#### Unit Testing

| Module | What to Test | Why It Matters |
|:---|:---|:---|
| `PrivacyService.redact()` | Email regex, BD phone (+88 01X), IN phone (+91), OTP extraction, mixed PII inputs, edge cases with no PII | PII leakage into history DB would violate GDPR/Play Store policy and destroy user trust |
| `TemplateEngine.generate()` | All 7 languages × 6 tones × 11 intents (462 combinations); verify non-empty, non-null, exactly 3 unique results | A single missing template combination causes blank reply cards — direct user-facing failure |
| `ReplyNotifier.detectIntent()` | Each of the 11 `MessageIntent` enums triggers on its expected keywords; verify `general` fallback when no keyword matches | Incorrect intent detection produces irrelevant replies, making the app useless |
| `HistoryService` | CRUD: addHistoryItem, getHistory (max 20 cap), toggleFavorite, clearHistory, generation/regeneration counters (increment, reset, persistence) | Counter bugs bypass the ad monetization wall — direct revenue loss |
| `ReplyState.copyWith()` | Immutability: verify original state unchanged after copyWith; all fields propagate correctly | State mutation bugs cause stale UI or lost user selections |

#### Integration Testing

| Integration Point | What to Test | Why It Matters |
|:---|:---|:---|
| OCR → Intent → Replies | Feed known text strings through `processImage()` simulation → verify correct intent detection → verify reply generation chain completes | This is the primary user journey; a break here means the entire app is non-functional |
| History Save on Generate | After `generateReplies()`, verify `HistoryService` contains the new entry with correct fields | Broken auto-save means users lose their reply history silently |
| Ad Counter → Dialog Trigger | Increment generation counter 3 times → verify 4th attempt triggers the ad dialog path, not free generation | Counter bypass = zero ad revenue |
| Language Switch → Regenerate | Switch language mid-session → verify replies regenerate in the new language immediately | Stale language replies confuse bilingual users |

#### End-to-End (E2E) Testing

| User Journey | What to Test | Why It Matters |
|:---|:---|:---|
| Fresh Install Flow | App launch → Onboarding → Language select → HomeScreen | First impression; a crash here means 1-star reviews and uninstalls |
| Screenshot Share Flow | Share image from WhatsApp → App opens → OcrPreview shows text → Generate → Results displayed | This is the headline feature users download the app for |
| 3-Generation Ad Wall | Generate 3 times → 4th triggers dialog → Watch ad → Counter resets → Free generation resumes | Revenue-critical path; must be bulletproof |
| Offline Complete Flow | Airplane mode → Camera capture → OCR → Generate → Copy → Share | The core USP; any network dependency here destroys the value proposition |

---

### 2. Edge Cases & Boundary Conditions

| Edge Case | What to Test | Why It Threatens Stability |
|:---|:---|:---|
| Empty OCR result | Screenshot with no readable text (blank image, solid color) | `detectIntent()` receives empty string; `generateReplies()` may produce nonsensical output or crash on empty array access |
| Extremely long OCR text | Screenshot of a full page of dense text (10,000+ chars) | History truncation at 100 chars must work; Hive storage must not OOM |
| Special characters in text | Emojis (🔥😂), Unicode (বাংলা + English mixed), RTL scripts, HTML entities | Regex in `PrivacyService` may break; `TemplateEngine` string concatenation may corrupt |
| Unsupported language in TemplateEngine | Pass language string "Japanese" (not in template map) | Null map access → `.cast<String>()` on null throws TypeError |
| History at max capacity (20) | Add 21st item → verify oldest is removed, not newest | Array index bugs lose recent data |
| Generation counter at exactly 3 | Counter = 3 → next action must show dialog, not counter = 2 (off-by-one) | Off-by-one means users get 4 free or only 2 free actions |
| Rapid double-tap on Generate | User taps "Generate Replies" twice very fast | Duplicate history entries, double counter increment, or concurrent state mutation |
| OTP-like numbers without OTP context | Text "Call me at 4pm, room 1234" — should NOT redact "1234" since no OTP/code keyword present | Over-redaction corrupts the input text, producing irrelevant replies |
| Image file not found | `processImage()` called with deleted/invalid file path | Unhandled file I/O exception crashes the app |

---

### 3. Load & Scalability Concerns

| Concern | What to Test | Why It Matters |
|:---|:---|:---|
| Hive box size growth | Simulate 1000+ history entries (beyond the 20-cap) — verify cap enforcement | Uncapped Hive growth degrades cold-start time and consumes storage |
| TemplateEngine memory footprint | Profile memory after loading all 1,386 template strings into const maps | On low-RAM devices (1-2 GB), large const maps may cause jank during first access |
| OCR processing time | Benchmark `processImage()` on images of varying resolution (480p to 4K) | 4K screenshots on budget phones may cause ANR (Application Not Responding) |
| Rapid regeneration | Tap "Regenerate" 50 times in quick succession | Memory leaks from unreleased state objects; UI thread starvation |
| Banner ad reload frequency | Navigate Home → away → Home → away 100 times | Banner ad recreation without disposal leaks native ad objects |

---

### 4. Async vs. Sync Behavior

| Operation | Sync/Async | What to Test | Why It Matters |
|:---|:---|:---|:---|
| `HistoryService.init()` | Async | Must complete before `runApp()` — verify `await` is honored | If Hive isn't initialized, all DB reads throw "Box not open" |
| `processImage()` | Async | UI must show loading state while OCR runs; result must update state when complete | Sync access to incomplete OCR result shows "Processing OCR..." as permanent text |
| `MobileAds.instance.initialize()` | Async | Must not block app startup; try-catch must swallow failures gracefully | Without try-catch, a missing AdMob config crashes the app before UI renders |
| `Firebase.initializeApp()` | Async | Same as above — must fail silently without `google-services.json` | Firebase crash on init = app won't open at all |
| `HistoryService.addHistoryItem()` | Async | `generateReplies()` calls this but does NOT await it — verify no data loss | Fire-and-forget writes may lose data if app is killed immediately after |
| `AdManager.loadRewardedAd()` | Async (callback) | Preload starts at launch; ad may not be ready when user hits limit at 4th gen | Null ad → `showRewardedAd()` fallback must grant access, not block user |

---

### 5. Concurrency Issues

| Risk Area | What to Test | Why It Matters |
|:---|:---|:---|
| StateNotifier mutation during async OCR | User changes tone while `processImage()` is still running | `state = state.copyWith()` from two paths simultaneously may overwrite each other; OCR result may clobber tone change |
| Double-tap on Generate button | Two `generateReplies()` calls fire before first completes | Double history write, double counter increment — revenue counter becomes inaccurate |
| Sharing intent while on OcrPreviewScreen | User shares a new screenshot while editing text from a previous screenshot | `_handleSharedFile()` calls `reset()` then `processImage()` — if previous OCR is in-flight, state may be corrupted |
| Hive concurrent writes | `addHistoryItem()` and `incrementGenerationCount()` write to same box simultaneously | Hive is single-isolate safe but not multi-write atomic — last write wins, may lose one operation |
| Ad callback + Navigator | Ad dismissed callback fires while user has already navigated away | Calling `ref.read(replyProvider.notifier).generateReplies()` on a disposed widget throws FlutterError |

---

### 6. Failure Scenarios & Resilience

| Failure Mode | What to Test | Recovery Expectation |
|:---|:---|:---|
| ML Kit initialization failure | Device lacks Google Play Services or ML Kit download fails | `processImage()` catch block must show user-friendly error text, not crash |
| AdMob network timeout | Device online but ad server unreachable (DNS failure, firewall) | Banner: `SizedBox.shrink()` (invisible). Rewarded: fallback grants free access |
| Hive database corruption | Force-kill app during Hive write → reopen | Hive must recover gracefully; worst case: empty history (not crash) |
| Firebase missing config | `google-services.json` deleted or malformed | `try-catch` in `main()` must swallow; app runs without analytics |
| Out of storage | Device has <10MB free space, Hive write fails | Catch `HiveError` → continue without saving; do not crash |
| Image picker cancellation | User opens camera/gallery then presses back without selecting | `ImagePicker` returns null → app must stay on HomeScreen, not navigate to OcrPreview |
| Share intent with non-image file | User shares a PDF or video to Reply Snap | `processImage()` OCR fails → error message displayed; no crash |

---

### 7. Data Consistency Risks

| Risk | What to Test | Why It Matters |
|:---|:---|:---|
| Generation counter vs. actual generations | After 3 generations + ad watch + reset → counter must be exactly 0, not negative or stale | Counter drift means users get infinite free gens (revenue loss) or are permanently locked (UX disaster) |
| Regenerate counter independence | Generation counter and regeneration counter must be completely independent | If they share a key, watching ad for regeneration also resets generation counter — double the free usage |
| History deduplication | Same input text + same tone + same language → must NOT create duplicate history entry | Duplicate entries waste storage and confuse users |
| Favorites survival after history clear | `clearHistory()` must NOT delete favorites list | Users expect favorites to persist; shared Hive box key collision would wipe both |
| First-launch flag persistence | `setFirstLaunchCompleted()` must persist across app restarts | If flag resets, user sees onboarding every launch — extremely annoying |
| State restoration after process death | Android kills app in background → user returns → verify Hive data intact | Hive writes are immediate (not buffered), so data should survive; but incomplete async writes may be lost |
| ReplyState immutability | Verify `copyWith()` does not mutate the `generatedReplies` list reference | If original list is mutated, previous states held by Riverpod become corrupted — UI shows wrong data |

---

## Test Coverage Priority Matrix

| Priority | Module | Risk Level | Revenue Impact |
|:---|:---|:---|:---|
| 🔴 P0 | Generation/Regeneration counter logic | Critical | Direct — ad wall bypass = $0 revenue |
| 🔴 P0 | TemplateEngine (all 462 combos) | Critical | Direct — empty replies = uninstalls |
| 🔴 P0 | PrivacyService redaction | Critical | Compliance — PII leak = Play Store removal |
| 🟠 P1 | AdManager fallback paths | High | Revenue — broken ads = lost impressions |
| 🟠 P1 | OCR → Intent → Reply chain | High | Core UX — broken chain = useless app |
| 🟡 P2 | History CRUD + cap enforcement | Medium | UX — data loss frustrates users |
| 🟡 P2 | Async init order (Hive, Ads, Firebase) | Medium | Stability — wrong order = startup crash |
| 🟢 P3 | UI edge cases (double-tap, rotation) | Low | Polish — annoying but not fatal |
| 🟢 P3 | Theme/NeomorphicButton states | Low | Visual — no functional impact |

---

*Generated: July 11, 2026*
*Scope: Reply Snap v1.0.0+1 (com.farkode.replysnap)*
*Strategy Only — No Test Code Included*

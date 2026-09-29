# AgoraCare Flutter — Product Requirements Document
### Agora Voice AI Hackathon 2026 | 1st Prize Submission

**Version:** 1.0  
**Target:** Android APK (Flutter)  
**Hackathon Deadline:** 29 September 2026  
**Prize Pool:** ₹30,000 | Goal: 🥇 1st Prize (₹15,000)

---

## 1. The One-Line Pitch

> **AgoraCare** — A real-time Hindi/English Voice AI healthcare companion for rural India that lets patients talk to an AI doctor, get medication reminders, and instantly connect to a live nurse in emergencies — all by voice, on any Android phone.

---

## 2. Why This Wins

The judging criteria map perfectly to what we're building:

| Judging Criterion | Our Advantage |
|---|---|
| **Innovation** | Human-in-the-loop nurse escalation via live Agora RTC audio bridge. No other team will have this. |
| **Technical Implementation** | Native Flutter + `agora_rtc_engine` (not web). Reliable, battle-tested, runs on ₹5,000 Android phones. |
| **Effective Use of Agora Conversational AI** | Agora Convo AI is the *only* way to talk to the app. It's not a feature — it's the entire UX. |
| **User Experience** | One-tap voice orb. No typing. Works for elderly, semi-literate, and rural users. |
| **Real-World Impact** | 65% of India lives in rural areas with limited healthcare access. This solves a real problem judges understand. |

---

## 3. Problem Statement

Rural and semi-urban India faces a critical healthcare access gap:
- 1 doctor per 1,456 people in rural India (WHO standard: 1 per 1,000)
- Elderly patients forget medications — non-adherence causes 125,000 deaths/year in India
- Emergency response is slow — patients don't know when to escalate
- Language barrier — most health apps are English-only

**AgoraCare solves this with voice.** A patient in a village can tap one button, speak in Hindi, and get real medical guidance, medication reminders, and emergency help — without typing a single word.

---

## 4. Core User Personas

### Persona 1: Ramesh, 68, Retired Farmer (Primary)
- Lives in rural Rajasthan, takes 4 medications daily
- Forgets doses, can't read English app labels
- Needs: Hindi voice reminders, simple one-tap interface

### Persona 2: Priya, 34, Caregiver Daughter (Secondary)
- Manages her father's health remotely from Jaipur
- Needs: Real-time alerts when father misses meds or has emergency

### Persona 3: Nurse Kavita, 29, Triage Nurse (Tertiary)
- Receives escalated emergency calls from AI
- Needs: Clean dashboard, instant audio bridge to patient

---

## 5. App Architecture

```
┌─────────────────────────────────────────────────────┐
│              Flutter Android App                     │
│                                                      │
│  ┌──────────────┐    ┌──────────────────────────┐   │
│  │  Voice Orb   │───▶│  Agora RTC Engine        │   │
│  │  (one tap)   │    │  agora_rtc_engine: ^6.x   │   │
│  └──────────────┘    └──────────────────────────┘   │
│                                ↕ audio stream        │
│                      ┌──────────────────────────┐   │
│                      │  Agora Conversational AI  │   │
│                      │  Agent "Aria"             │   │
│                      │  (Hindi + English)        │   │
│                      └──────────────────────────┘   │
│                                ↕ tool calls          │
│  ┌──────────────────────────────────────────────┐   │
│  │         AgoraCare Backend (Vercel)            │   │
│  │  /api/agora/agent/start  (Next.js)            │   │
│  │  /api/agora/agent/tool   (emergency webhook)  │   │
│  │  Firebase Firestore      (data persistence)   │   │
│  └──────────────────────────────────────────────┘   │
│                                ↕ Firestore           │
│  ┌──────────────────────────────────────────────┐   │
│  │         Nurse Dashboard Screen               │   │
│  │  (in-app, real-time escalation tickets)      │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

**Key architectural decision:** The Flutter app calls the existing Next.js backend API on Vercel. We do NOT rewrite the backend. Flutter is purely the mobile client.

---

## 6. Screens & Navigation

```
SplashScreen
    └── OnboardingScreen (language select: Hindi / English)
            └── AuthScreen (Google Sign-In via Firebase)
                    └── HomeScreen (bottom nav: 4 tabs)
                            ├── Tab 1: VoiceScreen       ← CORE FEATURE
                            ├── Tab 2: MedicationsScreen
                            ├── Tab 3: VitalsScreen
                            └── Tab 4: ProfileScreen

                    └── NurseDashboardScreen (separate route, /nurse)
```

---

## 7. Screen-by-Screen Specifications

---

### 7.1 SplashScreen
- AgoraCare logo + tagline animation (1.5s)
- Check Firebase auth state → route to Onboarding or Home
- Background: deep medical blue gradient (`#0A1628` → `#1E3A5F`)

---

### 7.2 OnboardingScreen
**Purpose:** Language selection + value proposition  
**3 swipeable cards:**
1. "Talk to your AI doctor in Hindi or English" — mic animation
2. "Never miss a medication" — pill + clock animation
3. "Emergency? We connect you to a real nurse instantly" — pulse animation

**Bottom CTA:** "Get Started" → AuthScreen  
**Language toggle:** Hindi / English (persisted to SharedPreferences)

---

### 7.3 AuthScreen
- Google Sign-In button (Firebase Auth)
- Clean, minimal — logo + single button
- On success → HomeScreen

---

### 7.4 HomeScreen (Shell)
**Bottom Navigation Bar — 4 tabs:**
- 🎙️ Voice (default active)
- 💊 Medications
- 📊 Vitals
- 👤 Profile

**Top AppBar:**
- "AgoraCare" wordmark left
- Notification bell icon right (badge for missed meds)
- Language toggle (HI / EN) — switches AI language live

---

### 7.5 VoiceScreen ← THE MOST IMPORTANT SCREEN

**This is the entire product. Everything else supports this.**

#### Layout:
```
┌─────────────────────────────────┐
│  [Status Bar]                   │
│                                 │
│  ┌─────────────────────────┐   │
│  │   AI Status Card        │   │
│  │   "Aria is listening..." │   │
│  │   [animated waveform]   │   │
│  └─────────────────────────┘   │
│                                 │
│         [VOICE ORB]             │
│    ╔═══════════════════╗        │
│    ║  🎙️              ║        │
│    ║  Tap to Talk      ║        │
│    ║  (pulsing ring)   ║        │
│    ╚═══════════════════╝        │
│                                 │
│  ┌─────────────────────────┐   │
│  │  Transcript Card        │   │
│  │  [scrollable chat log]  │   │
│  └─────────────────────────┘   │
│                                 │
│  [🚨 Emergency Button]          │
│  "Tap for immediate help"       │
└─────────────────────────────────┘
```

#### Voice Orb States:
| State | Visual | Color |
|---|---|---|
| Idle | Slow pulse, 80px | Medical blue `#2563EB` |
| Connecting | Spinning ring | Amber `#F59E0B` |
| Listening (user speaking) | Fast pulse, 120px | Green `#10B981` |
| AI Speaking | Waveform animation | Purple `#7C3AED` |
| Emergency | Rapid red pulse | Red `#EF4444` |

#### Behavior:
1. User taps orb → app calls `POST /api/agora/agent/start` with language + patient context
2. Flutter joins Agora RTC channel via `agora_rtc_engine`
3. Agora Convo AI Agent "Aria" joins same channel (UID 9999)
4. Bidirectional audio flows — user speaks, Aria responds
5. Transcript appears in real-time below orb
6. Tap orb again → graceful disconnect

#### Emergency Button:
- Always visible, bottom of screen
- Tapping triggers `escalateToHumanNurse` tool call directly
- Aria announces: "Connecting you to Nurse Kavita now..."
- Nurse dashboard receives real-time Firestore alert

---

### 7.6 MedicationsScreen

**Purpose:** View today's medication schedule, mark as taken

#### Layout:
- Header: "Today's Schedule" + date
- Timeline list: medications sorted by time
  - Each card: pill name, dose, time, status chip (Upcoming / Due Now / Taken / Missed)
  - "Mark Taken" button → updates Firestore adherence record
- Bottom: "Ask Aria about my meds" → opens VoiceScreen with medication context pre-loaded
- Adherence ring chart (today's %) at top

#### Medication Cards:
```
┌────────────────────────────────┐
│ 💊 Lisinopril 10mg             │
│    8:00 AM  •  Morning         │
│                    [✓ Taken]   │
└────────────────────────────────┘
```

---

### 7.7 VitalsScreen

**Purpose:** Log and visualize cardiovascular vitals

- Blood pressure input (systolic/diastolic)
- Heart rate input
- SpO2 input
- Line chart (last 7 days) — `fl_chart` package
- Color-coded status: Normal / Elevated / Critical
- "Tell Aria my vitals" button → voice context injection

---

### 7.8 ProfileScreen

- User avatar + name (from Firebase Auth)
- Patient context: name, age, conditions, medications list
- Language preference toggle
- Emergency contacts (name + phone)
- "Nurse Mode" toggle → switches to NurseDashboardScreen

---

### 7.9 NurseDashboardScreen

**Purpose:** Human operator receives and responds to escalated emergencies

#### Layout:
- Header: "🚨 Live Escalations" + online indicator
- Active tickets list (real-time Firestore listener):
  ```
  ┌────────────────────────────────┐
  │ 🔴 CRITICAL                    │
  │ Patient: Ramesh Kumar          │
  │ "Chest pain, left arm"         │
  │ Channel: emergency_ch_1789     │
  │ 2 mins ago                     │
  │ [📞 Join Call]  [✓ Resolve]    │
  └────────────────────────────────┘
  ```
- "Join Call" → nurse joins same Agora RTC channel, hears patient live
- Alert sound plays on new ticket (using `audioplayers` package)

---

## 8. Agora Integration — Technical Spec

### 8.1 Flutter Package
```yaml
dependencies:
  agora_rtc_engine: ^6.3.2
```

### 8.2 Voice Session Flow
```dart
// 1. Get token from backend
final token = await BackendService.getAgoraToken(channelName, uid);

// 2. Initialize Agora RTC Engine
await _engine.initialize(RtcEngineContext(appId: AGORA_APP_ID));
await _engine.enableAudio();
await _engine.setAudioProfile(
  profile: AudioProfileType.audioProfileMusicHighQuality,
  scenario: AudioScenarioType.audioScenarioChatroom,
);

// 3. Join channel
await _engine.joinChannel(
  token: token,
  channelId: channelName,
  uid: userUid,
  options: const ChannelMediaOptions(
    clientRoleType: ClientRoleType.clientRoleBroadcaster,
    channelProfile: ChannelProfileType.channelProfileCommunication,
  ),
);

// 4. Start backend AI agent
await BackendService.startAgent(channelName, userUid, language);

// 5. Subscribe to remote audio (Aria, UID 9999)
_engine.onUserJoined = (connection, remoteUid, elapsed) {
  // Aria joined — audio auto-plays
};
```

### 8.3 Backend API Calls (reusing existing Next.js)
```dart
// Start agent
POST https://agoracare.vercel.app/api/agora/agent/start
Body: { channelName, agentUid: 9999, userUid, language, patientContext }

// Stop agent  
POST https://agoracare.vercel.app/api/agora/agent/stop
Body: { agentId, channelName }

// Get RTC token
POST https://agoracare.vercel.app/api/agora/token
Body: { channelName, uid }
```

### 8.4 Android Permissions (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
```

---

## 9. Firebase Integration

### 9.1 Collections Used
```
users/{uid}/
  - name, language, conditions, medications[]

medications/{uid}/schedule/
  - name, dose, time, frequency

adherence/{uid}/records/
  - date, medicationId, status, method

vitals/{uid}/readings/
  - timestamp, bp_systolic, bp_diastolic, heart_rate, spo2

escalations/
  - patientName, channelName, reason, severity, timestamp, status
```

### 9.2 Real-time Listeners
- `NurseDashboardScreen` listens to `escalations` collection
- `MedicationsScreen` listens to today's adherence records
- New escalation → local notification + alert sound

---

## 10. UI/UX Design System

### Color Palette
```
Primary:     #2563EB  (Medical Blue)
Background:  #0A1628  (Deep Navy)
Surface:     #1E2D3D  (Card Background)
Surface2:    #243447  (Elevated Card)
Success:     #10B981  (Emerald Green)
Warning:     #F59E0B  (Amber)
Danger:      #EF4444  (Red)
Text:        #F1F5F9  (Near White)
TextMuted:   #94A3B8  (Slate 400)
```

### Typography
```
Font: Inter (Google Fonts)
H1:  28sp, Bold
H2:  22sp, SemiBold
H3:  18sp, SemiBold
Body: 16sp, Regular
Caption: 13sp, Regular
```

### Design Principles
- **Glassmorphism cards:** `BackdropFilter` blur + semi-transparent backgrounds
- **Micro-animations:** Every state change has a smooth transition (300ms ease)
- **Large touch targets:** Minimum 56px for all interactive elements (elderly users)
- **High contrast:** WCAG AA compliant for outdoor visibility
- **Dark theme only:** Reduces eye strain, looks premium in demo

### Key Animations
- Voice Orb: `AnimationController` with `CurvedAnimation` for pulse
- Waveform: Custom `CustomPainter` with sine wave
- Screen transitions: Shared element transitions where possible
- Card entrance: Staggered `FadeTransition` + `SlideTransition`

---

## 11. Flutter Project Structure

```
agoracare_flutter/
├── android/
│   └── app/src/main/AndroidManifest.xml
├── lib/
│   ├── main.dart
│   ├── app.dart                          # MaterialApp, theme, routing
│   ├── core/
│   │   ├── constants.dart                # API URLs, Agora App ID
│   │   ├── theme.dart                    # Full design system
│   │   └── routes.dart                   # Named routes
│   ├── services/
│   │   ├── agora_service.dart            # RTC engine wrapper
│   │   ├── backend_service.dart          # HTTP calls to Next.js API
│   │   └── firebase_service.dart         # Firestore CRUD
│   ├── providers/
│   │   ├── voice_provider.dart           # Voice session state (Riverpod)
│   │   ├── medication_provider.dart
│   │   └── auth_provider.dart
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── onboarding_screen.dart
│   │   ├── auth_screen.dart
│   │   ├── home_screen.dart              # Bottom nav shell
│   │   ├── voice_screen.dart             ← PRIORITY 1
│   │   ├── medications_screen.dart       ← PRIORITY 2
│   │   ├── vitals_screen.dart            ← PRIORITY 3
│   │   ├── profile_screen.dart
│   │   └── nurse_dashboard_screen.dart   ← PRIORITY 4
│   └── widgets/
│       ├── voice_orb.dart                # Animated core widget
│       ├── waveform_painter.dart         # Custom painter
│       ├── medication_card.dart
│       ├── vitals_chart.dart
│       └── escalation_ticket_card.dart
├── pubspec.yaml
└── PRD.md
```

---

## 12. pubspec.yaml Dependencies

```yaml
name: agoracare_flutter
description: Voice AI Healthcare Companion — Agora Hackathon 2026
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # Agora — Core requirement
  agora_rtc_engine: ^6.3.2

  # Firebase
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  google_sign_in: ^6.2.1

  # State Management
  flutter_riverpod: ^2.5.1

  # HTTP
  dio: ^5.7.0

  # UI
  google_fonts: ^6.2.1
  fl_chart: ^0.69.0
  lottie: ^3.1.2

  # Audio
  audioplayers: ^6.1.0

  # Utils
  shared_preferences: ^2.3.2
  permission_handler: ^11.3.1
  intl: ^0.19.0
```

---

## 13. Build & Submission Plan

### Phase 1 — Foundation (Days 1–2)
- [ ] `flutter create agoracare_flutter`
- [ ] Add all dependencies to `pubspec.yaml`
- [ ] Set up Firebase project (Android SHA-1)
- [ ] Implement `theme.dart` (full design system)
- [ ] Build `SplashScreen`, `OnboardingScreen`, `AuthScreen`
- [ ] Verify Google Sign-In works on device

### Phase 2 — Core Voice (Days 3–5) ← MAKE OR BREAK
- [ ] Implement `AgoraService` (RTC engine init, join, leave)
- [ ] Implement `BackendService` (token fetch, agent start/stop)
- [ ] Build `VoiceOrb` widget with all 5 states + animations
- [ ] Build `VoiceScreen` end-to-end
- [ ] Test: tap orb → Aria speaks Hindi → user responds → Aria replies
- [ ] Test: emergency button → nurse dashboard alert fires

### Phase 3 — Supporting Screens (Days 6–7)
- [ ] `MedicationsScreen` with Firestore data
- [ ] `VitalsScreen` with `fl_chart` line chart
- [ ] `NurseDashboardScreen` with real-time Firestore listener
- [ ] `ProfileScreen` with language toggle

### Phase 4 — Polish & Demo Prep (Days 8–9)
- [ ] Micro-animations on all screens
- [ ] Staggered card entrance animations
- [ ] Test on real Android device (not just emulator)
- [ ] Seed demo data (Ramesh's medications, vitals)
- [ ] Record demo video (3–5 mins)
- [ ] Write project description (500 words)

### Phase 5 — Submission (Day 10)
- [ ] `flutter build apk --release`
- [ ] Push to GitHub (public repo)
- [ ] Submit: APK + GitHub link + demo video + description

---

## 14. Demo Script (for Video)

**Duration:** 3–4 minutes  
**Language:** English narration, Hindi/Hinglish in-app

```
0:00 — Problem statement (30s)
      "65% of India lives in rural areas. Meet Ramesh..."

0:30 — App launch + onboarding (30s)
      Show splash → language select → Google sign-in

1:00 — Voice interaction demo (90s)
      Tap orb → Aria greets in Hindi
      "Aria, meri dawai kab leni hai?" (When should I take my medicine?)
      Aria responds with medication schedule
      "Mujhe seene mein dard ho raha hai" (I have chest pain)
      Aria detects emergency → escalates

2:30 — Nurse dashboard (30s)
      Switch to nurse view → ticket appears → join call → hear patient

3:00 — Medications + Vitals screens (30s)
      Quick walkthrough of supporting features

3:30 — Closing (30s)
      "AgoraCare — Voice AI healthcare for every Indian"
```

---

## 15. Risk Mitigation

| Risk | Mitigation |
|---|---|
| Agora agent doesn't start | Test backend API independently with Postman first |
| Audio echo on device | Enable AEC in `agora_rtc_engine` audio profile |
| Hindi STT accuracy | Use Deepgram `nova-2` with `language: 'hi'` |
| Firebase cold start | Pre-warm backend with a health check call |
| APK too large | Use `--split-per-abi` flag in build |
| Demo device crashes | Test on 2 devices, have screen recording as backup |

---

## 16. What Makes This Submission Stand Out

1. **It actually works.** Native Flutter + `agora_rtc_engine` is reliable. No browser quirks.
2. **Real human escalation.** The nurse audio bridge is technically impressive and emotionally compelling in a demo.
3. **Hindi-first.** Judges are Indian developers. Hearing the app speak Hindi will land.
4. **One-tap UX.** The voice orb is instantly understandable. No learning curve.
5. **Real problem.** Healthcare access in rural India is a problem every Indian judge knows personally.
6. **Complete submission.** APK + video + GitHub + description. Many teams submit incomplete.

---

*AgoraCare Flutter — Built to win.*

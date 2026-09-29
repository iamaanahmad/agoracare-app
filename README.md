# AgoraCare — Voice AI Healthcare Companion for Rural India

> **Voice AI Hackathon 2026** · AI Mobile Coders × Agora · Submission

A real-time **Hindi/English Voice AI healthcare companion** for rural India. Patients tap one button, speak in Hindi, and talk to an AI doctor — get medication reminders, log vitals by voice, and get instantly connected to a **live human nurse** over an Agora audio bridge in emergencies. No typing. No English required. Built for ₹5,000 Android phones.

## Demo

🎥 **Demo video:** *(link to be added — 3–4 min walkthrough: voice consult in Hindi → medication reminder → emergency escalation → nurse dashboard)*

📱 **APK:** *(release APK to be attached)*

## The Problem

- 1 doctor per 1,456 people in rural India (WHO standard: 1 per 1,000)
- Elderly patients forget medications — non-adherence is a major cause of preventable harm
- Emergency response is slow — patients don't know when or how to escalate
- Language barrier — most health apps are English-only and text-first

**AgoraCare solves this with voice.** A 68-year-old farmer who can't read English can tap one button and speak.

## Key Features

| Feature | What it does |
|---|---|
| 🎙️ **One-tap Voice Orb** | Tap to talk to "Aria", the AI health companion, in Hindi or English. Real-time transcript below the orb. |
| 💊 **Medication management** | Today's schedule with status chips (Upcoming / Due Now / Taken / Missed) and an adherence ring |
| 📊 **Vitals tracking** | Blood pressure and heart-rate logging with 7-day trend charts |
| 🚨 **Emergency escalation** | One tap connects the patient to a **live nurse** via Agora RTC audio bridge; the nurse dashboard gets a real-time ticket with alert sound |
| 👩‍⚕️ **Nurse dashboard** | Real-time escalation tickets from Firestore — join the patient's audio channel or resolve |
| 🌐 **Hindi / English** | Full bilingual voice experience, switchable live |

## Why Agora Conversational AI Is the Core

Voice isn't a feature in AgoraCare — **it is the entire user experience**. Every interaction flows through Agora:

- `agora_rtc_engine` carries all real-time audio (patient ↔ AI agent "Aria")
- The backend starts an **Agora Conversational AI agent** in the patient's channel with their language + medical context
- Emergency escalation bridges a **live nurse into the same Agora channel** — human-in-the-loop, in real time

## Architecture

```
Flutter Android App
 ├── Voice Orb ──▶ Agora RTC Engine (agora_rtc_engine ^6.3.2)
 │                        ↕ audio stream
 │                 Agora Conversational AI Agent "Aria" (Hindi + English)
 │                        ↕ tool calls
 ├── Next.js Backend (Vercel)
 │    /api/agora/agent/start · /api/agora/agent/stop · /api/agora/token
 │                        ↕
 └── Firebase (Auth · Firestore)
      users · medications · adherence · vitals · escalations (real-time)
```

**Screens:** Splash → Onboarding (Hindi/English) → Anonymous sign-in → Home (4 tabs: Voice · Medications · Vitals · Profile) → Nurse Dashboard (real-time escalation view)

## Tech Stack

- **Mobile:** Flutter 3 (Dart), Riverpod state management
- **Voice AI:** Agora RTC Engine `^6.3.2` + Agora Conversational AI
- **Backend:** Next.js on Vercel (token server + agent lifecycle + emergency webhook)
- **Data:** Firebase Auth (anonymous sign-in), Cloud Firestore (real-time listeners)
- **UI:** Material 3 light theme, Inter font, custom waveform painter, fl_chart

## Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0 <4.0.0`
- An Agora project (App ID + App Certificate) with Conversational AI enabled
- Firebase project with Android app registered (google-services.json)
- The AgoraCare backend deployed (Next.js) — see `AppConstants.backendUrl` in `lib/core/constants.dart`

### Run

```bash
flutter pub get
flutter run
```

### Configure

1. `lib/core/constants.dart` — set your Agora App ID and backend URL
2. The Firebase Android API key is injected at build time and never committed:
   ```bash
   flutter run --dart-define=AGORACARE_FIREBASE_API_KEY=your-firebase-api-key
   ```
3. `flutter build apk --release --dart-define=AGORACARE_FIREBASE_API_KEY=your-key` (add `--split-per-abi` to keep the APK lean)

Android permissions required: `RECORD_AUDIO`, `INTERNET`, `BLUETOOTH`, `MODIFY_AUDIO_SETTINGS`.

## Project Structure

```
lib/
├── main.dart · app.dart
├── core/        # constants, theme (design system), routes
├── services/    # agora_service, backend_service, firebase_service
├── providers/   # voice, medication, auth (Riverpod)
├── screens/     # splash, onboarding, auth, home, voice,
│                # medications, vitals, profile, nurse dashboard
└── widgets/     # voice orb, waveform painter, cards, charts
```

Full product spec: [`PRD.md`](./PRD.md)

## Judging Criteria — How AgoraCare Maps

| Criterion | Our answer |
|---|---|
| Innovation | Human-in-the-loop nurse escalation via a live Agora RTC audio bridge |
| Technical Implementation | Native Flutter + `agora_rtc_engine` — reliable on low-end Android, no browser quirks |
| Effective Use of Agora Conversational AI | Voice AI is the whole UX, not a feature — every flow runs through it |
| User Experience | One-tap voice orb, 56px touch targets, large touch targets, clean light theme, Hindi-first voice |
| Real-World Impact | Built for the 65% of India in rural areas with limited healthcare access |

## Team

Built by **Amaan Ahmad** ([@iamaanahmad](https://github.com/iamaanahmad)) — Founder, CIT India — for the Voice AI Hackathon 2026 (AI Mobile Coders × Agora).

## License

MIT

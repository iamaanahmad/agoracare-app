# AgoraCare — Voice AI Healthcare Companion for Rural India

> **Voice AI Hackathon 2026** · AI Mobile Coders × Agora · Submission

A real-time **Hindi/English Voice AI healthcare companion** for rural India. Patients tap one button, speak in Hindi or English, and talk to **Aria** — an AI health companion powered by the **Agora Conversational AI Engine**. They get medication guidance, track vitals, and in an emergency get connected to a **live human nurse** over a shared Agora audio bridge. No typing. No English required. Built for ₹5,000 Android phones.

## Demo

🌐 **Live nurse dashboard (web):** https://agoracare.vercel.app/agent

📱 **Download the APK:** see the [latest Release](https://github.com/iamaanahmad/agoracare-app/releases/latest)

🎥 **Demo video:** *(3–4 min walkthrough: Hindi voice consult → medication reminder → emergency escalation → nurse joins the live audio bridge)*

## The Problem

- 1 doctor per 1,456 people in rural India (WHO standard: 1 per 1,000)
- Elderly patients forget medications — non-adherence is a major cause of preventable harm
- Emergency response is slow — patients don't know when or how to escalate
- Language barrier — most health apps are English-only and text-first

**AgoraCare solves this with voice.** A 68-year-old farmer who can't read English can tap one button and speak in Hindi.

## Key Features

| Feature | What it does |
|---|---|
| 🎙️ **One-tap Voice Orb** | Tap to talk to "Aria", the AI health companion, in Hindi or English. Live transcript and speaking-state animation. |
| 🗣️ **Bilingual, native voice** | English and **native Hindi** speech (MiniMax Hindi voice) — switchable live from the profile. |
| 💊 **Medication management** | Daily schedule with status chips (Upcoming / Due Now / Taken / Missed) and an adherence ring. Aria answers medication timing questions by voice. |
| 📊 **Vitals tracking** | Blood pressure and heart-rate logging with 7-day trend charts. |
| 🚨 **Emergency escalation** | One tap — or just telling Aria "I have chest pain" — raises a live escalation. Aria calls an `escalateToHumanNurse` tool that alerts the nurse dashboard in real time. |
| 👩‍⚕️ **Live nurse bridge** | A nurse accepts on the web dashboard and joins the **patient's exact Agora channel** for real two-way audio. Patient's screen flips Waiting → Connected and clears on resolve. |

## Why Agora Conversational AI Is the Core

Voice isn't a feature in AgoraCare — **it is the entire user experience**. Every interaction flows through Agora:

- `agora_rtc_engine` carries all real-time audio (patient ↔ AI agent "Aria", and patient ↔ nurse).
- The backend provisions an **Agora Conversational AI agent** in the patient's RTC channel with their language and medical context, using the official `agora-agents` SDK.
- The agent pipeline is **Agora-managed STT (Ares) → Google Gemini LLM (via Vertex AI) → Agora-managed MiniMax TTS** (English + native Hindi voices).
- Emergency escalation is driven by an **LLM tool call** and bridges a **live human nurse into the same Agora channel** — human-in-the-loop, in real time.

## Architecture

```
Flutter Android App (patient)
 ├── Voice Orb ──▶ Agora RTC Engine (agora_rtc_engine ^6.3.2)
 │                        ↕ real-time audio (LIVE_BROADCASTING channel)
 │                 Agora Conversational AI Agent "Aria" (UID 9999)
 │                   STT: Agora Ares  ·  LLM: Gemini (Vertex AI)  ·  TTS: MiniMax
 │                        ↕ escalateToHumanNurse tool call
 ├── Next.js Backend (Vercel · https://agoracare.vercel.app)
 │    /api/agora/token              → RTC token issuer
 │    /api/agora/agent/start|stop   → Convo AI agent lifecycle (agora-agents SDK)
 │    /api/agora/llm/chat/completions → OpenAI-compatible LLM proxy → Vertex AI
 │                                      (runs the tool-calling loop server-side,
 │                                       writes escalations to Firestore)
 │                        ↕
 ├── Firebase (Auth · Firestore, real-time)
 │    medications · adherence · vitals · escalations · support_tickets
 │                        ↕
 └── Web Nurse Dashboard (/agent) ──▶ joins the patient's Agora channel for 2-way audio
```

**Why an LLM proxy?** The Agora agent (running in Agora's cloud) talks to the LLM over the OpenAI protocol with a static key, but Vertex AI uses short-lived OAuth tokens. The backend exposes an OpenAI-compatible endpoint that authenticates to Vertex with the GCP service account — giving reliable, quota-backed inference and a server-side tool-calling loop (so the emergency escalation is written to Firestore the moment Aria decides to escalate).

**Screens:** Splash → Onboarding (Hindi/English) → Anonymous sign-in → Home (Voice · Medications · Vitals · Profile) → Nurse Dashboard (real-time escalations).

## Tech Stack

- **Mobile:** Flutter 3 (Dart), Riverpod state management
- **Voice AI:** `agora_rtc_engine ^6.3.2` + Agora Conversational AI Engine (`agora-agents` SDK)
- **LLM:** Google Gemini via **Vertex AI** (OpenAI-compatible proxy)
- **Speech:** Agora-managed Ares STT + MiniMax TTS (English + native Hindi)
- **Backend:** Next.js on Vercel — token server, agent lifecycle, LLM proxy, emergency tool webhook
- **Data:** Firebase Auth (anonymous sign-in), Cloud Firestore (real-time listeners)
- **UI:** Material 3 light theme, Inter font, custom waveform painter, fl_chart

## Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0 <4.0.0`, Android toolchain, JDK 17
- An Agora project (App ID + App Certificate + Customer ID/Secret) with Conversational AI enabled
- Firebase project with the Android app registered
- The AgoraCare backend deployed (default points at `https://agoracare.vercel.app`)

### Run

```bash
flutter pub get
flutter run
```

The app ships pointing at the live Vercel backend (`AppConstants.backendUrl`). For a local backend, set it to `http://localhost:9002` and run `adb reverse tcp:9002 tcp:9002`.

### Build a release APK

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

The Firebase Android API key has a safe default baked in; to override at build time:

```bash
flutter build apk --release --dart-define=AGORACARE_FIREBASE_API_KEY=your-key
```

Android permissions required: `RECORD_AUDIO`, `INTERNET`, `MODIFY_AUDIO_SETTINGS`.

> **Note on the emergency audio bridge:** two-way human audio needs two endpoints — the patient on the phone and the nurse on the web dashboard (`/agent`) or a second device. A single app instance uses one Agora engine, so patient and nurse cannot both be live participants on the same device.

## Project Structure

```
lib/
├── main.dart · app.dart
├── core/        # constants, theme (design system), routes
├── services/    # agora_service, backend_service, firebase_service
├── providers/   # voice (session + emergency lifecycle), auth, language (Riverpod)
├── screens/     # splash, onboarding, auth, home, voice,
│                # medications, vitals, profile, nurse dashboard
└── widgets/     # voice orb, waveform painter, cards, charts
```

## Judging Criteria — How AgoraCare Maps

| Criterion | Our answer |
|---|---|
| Innovation | Human-in-the-loop nurse escalation via a live Agora RTC audio bridge, triggered by an LLM tool call |
| Technical Implementation | Native Flutter + `agora_rtc_engine`; server-side Convo AI with Vertex AI LLM proxy and tool calling |
| Effective Use of Agora Conversational AI | Voice AI is the whole UX — STT → LLM → TTS and the emergency bridge all run through Agora |
| User Experience | One-tap voice orb, large touch targets, clean light theme, Hindi-first bilingual voice |
| Real-World Impact | Built for the 65% of India in rural areas with limited healthcare access |

## Team

Built by **Amaan Ahmad** ([@iamaanahmad](https://github.com/iamaanahmad)) for the Voice AI Hackathon 2026 (AI Mobile Coders × Agora).

## License

MIT

# AgoraCare — Submission Project Description
*(Paste-ready for the Commudle submission form — ~350 words)*

---

**AgoraCare** is a real-time Hindi/English Voice AI healthcare companion for rural India — built with **Agora Conversational AI at its core**.

**The problem.** Rural India has 1 doctor per 1,456 people (WHO standard: 1 per 1,000). Elderly patients forget medications, emergency response is slow, and most health apps are English-only and text-first — unusable for the millions who need them most.

**The solution.** A patient taps one button, speaks in Hindi, and talks to "Aria", an AI health companion — getting medical guidance, medication reminders, and vitals logging, all by voice. In an emergency, one tap bridges a **live human nurse** into the call over Agora RTC, with a real-time escalation ticket landing on the nurse dashboard. No typing. No English required. It runs on a ₹5,000 Android phone.

**How Agora powers it (not a feature — the entire UX):**
- Every conversation flows through **Agora Conversational AI** — the agent joins the patient's RTC channel with their language and medical context.
- Real-time bidirectional audio via **agora_rtc_engine** (native Flutter, tuned for low-end devices).
- Emergency escalation is a **live nurse audio bridge** in the same Agora channel — human-in-the-loop voice AI.

**Key features:** one-tap animated voice orb (5 states) with live transcript · medication schedule with adherence tracking · vitals logging (BP, heart rate) with 7-day trend charts · nurse dashboard with real-time escalation tickets and one-tap call join · full Hindi/English bilingual voice experience.

**Tech stack:** Flutter 3 (Riverpod) · agora_rtc_engine 6.3.2 + Agora Conversational AI · Next.js backend on Vercel (token server, agent lifecycle, emergency webhook) · Firebase Auth + Firestore (real-time listeners).

**Why it matters:** 65% of India lives in rural areas with limited healthcare access. AgoraCare is designed for exactly those users — elderly, semi-literate, Hindi-speaking — with 56px touch targets, WCAG AA contrast, and a zero-learning-curve voice interface. The roadmap: pilot with rural clinics, ASHA worker mode, and IVR fallback for non-smartphones.

**Links:** GitHub (public): github.com/iamaanahmad/agoracare-app · Demo video: [link] · Pitch deck: [attached] · Built by Amaan Ahmad, Founder, CIT India.

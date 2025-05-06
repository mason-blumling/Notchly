# Notchly

<div align="center">

![Icon-256](https://github.com/user-attachments/assets/a8821599-f304-4a76-bbdd-77d38af7a571)
![Icon-256](https://github.com/user-attachments/assets/a8821599-f304-4a76-bbdd-77d38af7a571)
![Icon-256](https://github.com/user-attachments/assets/a8821599-f304-4a76-bbdd-77d38af7a571)

**Notchly** transforms the underutilized notch area on MacBooks into a buttery-smooth productivity hub.  
Inspired by iPhone’s Dynamic Island. Built with SwiftUI. Backed by modular, real-time logic.

</div>

---

## Vision

Notchly turns the notch into a dynamic space for productivity — blending calendar, media, and live activity intelligence into a beautiful, hover-triggered interface.

---

## V2.0.0 & V2.5.0 Highlights

### ✨ All-New Onboarding

- Modular intro flow driven by SwiftUI enums (`IntroStage`, `LogoAnimationState`)
- Animated path-drawing logo, rainbow transitions, and text reveal using native SwiftUI effects
- Permission request logic that’s non-blocking, sandbox-friendly, and fully lifecycle-aware

> _See [`fd8b321`](https://github.com/mason-blumling/Notchly/commit/fd8b3210ebcba2aa98da80d6962da98120811a99) for this milestone._

### 🚀 New Features

- **Media Player Live Activities**  
  Compact "now playing" controls auto-appear in the notch when music plays.

- **Calendar Live Activities**  
  Pulsing notch alerts appear 15, 5, and 1 minute before upcoming events — with countdowns.

- **Centralized App Environment**  
  SwiftUI `.environmentObject` injection now powers shared state across the app.

- **NotchlyIntro**  
  A delightful animated experience that introduces users to the notch with custom transitions, spring physics, and state-bound SwiftUI sequences.

### 💡 UX & Animation Improvements

- **Perfectly Timed Transitions**  
  Matched geometry, spring physics, and new animation helpers ensure a polished, native feel.

- **Live Syncing**  
  Calendar and media changes update the notch in real time — no hover needed.

- **Intro-Driven Notch Expansion**  
  The app's first-launch experience now visually expands the notch as part of the welcome animation.

---

## What’s Already Inside

### 📅 Calendar Module

- Smart event grouping, attendee logic, conflict detection
- Auto-scroll to next event
- SwiftUI-native event list and height animation
- Live countdowns before meetings

### 🎵 Media Module

- Apple Music + Spotify support
- Animated artwork glow + fallback states
- Scrubber, controls, and hover transitions
- Modular subviews for artwork, audio bars, metadata, and controls

### 🖥️ Notch UI

- Three states: Collapsed, Activity, Expanded
- Springy bounce feedback + shape morphing
- Custom notch shape rendering per display
- Lightweight hover detection + debounce logic
- LiveActivityView: unified layout for calendar + media overlays

---

## Coming Soon

- **Window Docking & Resize**  
  Drag other windows to the notch to dock them into supported zones.

- **Weather Overlay**  
  Real-time forecast inside the notch (in compact mode).

- **Clipboard & Airdrop Tracking**  
  Let the notch reflect system transfers and copy history without breaking flow.

- **AI-Powered Assist**  
  Summarize events, suggest music, auto-respond to meetings.

- **Sparkle Updates**  
  One-click version checks + automatic update support.

---

## Getting Started

### Requirements

- macOS 14.0+
- Xcode 15+
- A MacBook with a notch (M1 Pro or newer preferred)

### Installation

```bash
git clone https://github.com/mason-blumling/Notchly.git
cd Notchly
open Notchly.xcodeproj

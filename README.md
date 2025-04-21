# Notchly

<div align="center">

![Icon-256](https://github.com/user-attachments/assets/a8821599-f304-4a76-bbdd-77d38af7a571)
![Icon-256](https://github.com/user-attachments/assets/a8821599-f304-4a76-bbdd-77d38af7a571)
![Icon-256](https://github.com/user-attachments/assets/a8821599-f304-4a76-bbdd-77d38af7a571)

Notchly is a macOS app that transforms the underutilized notch area on MacBook displays into a dynamic productivity hub. Inspired by the iPhone's Dynamic Island, Notchly combines elegance with powerful functionality to enhance your user experience through seamless tool integration and smooth animations.
</div>

---

## Vision

Notchly aims to create a lightweight, user-friendly app that unlocks the full potential of your MacBook's notch by turning it into a dynamic space for productivity and interaction.

---

## V2.0.0 Highlights

### 🚀 New Features

- **Media Player Live Activities**  
  Displays compact now-playing info in the notch when media is playing but not expanded.

- **Calendar Live Activities**  
  Heads-up alerts appear in the notch 15m, 5m, and 1m before your next event — including countdown mode.

- **Centralized App Environment**  
  SwiftUI environment injection makes state and data flow more robust and scalable.

- **Modular Architecture**  
  Media and calendar systems are now fully modularized for easier maintenance and cleaner transitions.

### 💡 UX & Animation Improvements

- **Perfectly Timed Transitions**  
  Matched geometry, spring physics, and new animation helpers ensure buttery smooth expansion/contraction.

- **Live Syncing**  
  Notch state reflects real-time changes from Calendar and Media without needing to hover.

- **Adaptive Layouts**  
  Views now respect notch constraints and prevent visual bounce, overflow, or ghosting.

### 🧼 Codebase Cleanup

- **Memory & Performance Improvements**  
  All timers, observers, and polling systems now respect lifecycle. Memory leaks resolved.

- **Calendar + Media Overhaul**  
  The entire stack was cleaned up to reduce redundant logic and better handle edge cases.

- **Refined Logging + State Observers**  
  Less spammy logging. Improved real-time debug output for playback, event triggers, and lifecycle changes.

---

## What’s Already Inside

### 📅 Calendar Module

- Smart event grouping, attendee logic, conflict detection
- Auto-scroll to next event
- Dynamic height adjustment
- SwiftUI-native animations

### 🎵 Media Module

- Apple Music + Spotify playback
- Album artwork glow effect
- Track info, controls, and scrubber
- Idle fallback for no playback
- Podcast support (fallback only for now)

### ✨ Notch UI

- Three modes: Collapsed, Activity, Expanded
- Springy transitions and bounce feedback
- Custom shape rendering per display
- Hover detection with debounce logic
- Lightweight matchedGeometryEffect implementation

---

## Coming Soon

- **Window Resizing & Placement**  
  Drag a window to the notch and let go to anchor + resize it to a supported area.

- **Live Weather**  
  Pull real-time forecast data directly into the notch.

- **Airdrop + Clipboard Features**  
  View current transfers or copied content without leaving your flow.

- **AI-Based Features**  
  Smart summaries, event suggestions, media cueing, and more.

- **Performance Optimizations**  
  Additional energy use and memory profiling for long idle use.

- **Sparkle Update Support**  
  Built-in “Check for Updates” button with background version tracking.

---

## Getting Started

### Requirements

- macOS 14.0+
- Xcode 15+
- A Mac with a notch (MacBook Pro or Air with Apple Silicon preferred)

### Installation

```bash
git clone https://github.com/mason-blumling/Notchly.git
cd Notchly
open Notchly.xcodeproj

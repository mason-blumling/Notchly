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

## V1 Features

- **Calendar Integration**  
  - Display upcoming events, reminders, and appointments.  
  - Quick access to detailed schedules by hovering over or clicking the notch.  
  - Syncs with iCloud Calendar and other calendar services.

- **Music Control**  
  - Displays now-playing information and media controls.  
  - Shows album art and progress bars with subtle, elegant animations.  
  - Integrates with Apple Music, Spotify, and other media apps.

- **Simple, Animated UI**  
  - Enjoy smooth transitions and micro-interactions for a polished experience.  
  - Subtle feedback (haptic or sound cues) enhances interactions.

<div align="center">

<a href="https://github.com/mason-blumling/Notchly/releases/download/v1.0.0/Notchly.zip" target="_self">
  <img src="https://www.adviksoft.com/blog/wp-content/uploads/2023/09/editor_download_mac.png" alt="Download Notchly" width="160">
</a>

*Note: On first launch, you may see a security warning. Simply click **Open Anyway** in System Preferences → Security & Privacy.*
</div>

---

## File Map (Documentation)

Here’s a plain-English breakdown of the entire project — what each file does, and how the parts connect:

### 🧠 Core App Structure
- `NotchlyApp.swift`: App entry point. Initializes `MenuBarController`, sets up SwiftUI environment.
- `Notchly.swift`: Main app controller. Manages window, hover tracking, content transitions.
- `NotchlyView.swift`: Visual layout logic. Hosts calendar/media modules based on state.
- `NotchlyConfigurations.swift`: Defines notch size presets (Collapsed, Activity, Expanded).
- `NotchlyWindowPanel.swift`: Custom NSPanel subclass for notch-level behavior.

### 📅 Calendar Module
- `CalendarManager.swift`: Handles permissions + fetching events using EventKit.
- `NotchlyCalendarView.swift`: Full calendar view inside the notch.
- `NotchlyDateSelector.swift`: Horizontally scrolling date picker.
- `NotchlyEventList.swift`: Shows daily events with status (pending, conflict, etc.).
- `NotchlyCalendarUtilities.swift`: Shared utilities like date formatters.
- `UserEmailCache.swift`: Caches user’s calendar email addresses.
- `NotchlyEventAttendees.swift`: Detects declined/tentative attendees.
- `NotchlyEventConflicts.swift`: Highlights overlapping calendar events.
- `RenderSafeView.swift`: Optimizes GPU rendering for blur-heavy views.

### 📆 Calendar Live Activities
- `CalendarLiveActivityMonitor.swift`: Observes events starting in 15m/5m/1m.
- `CalendarLiveActivityView.swift`: UI for upcoming event warnings.
- `NotchlyCalendarLiveActivity.swift`: Extension to get “next starting soon” event.

### 🎵 Media Player
- `MediaPlaybackMonitor.swift`: Core state manager for now-playing info.
- `UnifiedMediaPlayerView.swift`: Morphs between compact/expanded media views.
- `NotchlyMediaPlayer.swift`: Expanded media controls (title, controls, scrubber).
- `MediaControlsView.swift`: Play/pause/skip buttons.
- `TrackInfoView.swift`: Displays title + artist.
- `TrackScrubberView.swift`: Drag-enabled time scrubber.
- `MediaPlayerIdleView.swift`: Shown when no media is active.
- `PodcastsFallbackView.swift`: Friendly fallback when Podcasts lacks control support.
- `ArtworkContainerView.swift`: Manages artwork display with glow + app icon overlay.
- `ArtworkView.swift`: Displays image or placeholder.
- `AudioBarsView.swift`: Animated bars for compact media view.
- `LavaLampGlowView.swift`: Dynamic blob background for expanded view.
- `BouncingBlobView.swift`: Self-bouncing glow blobs used by the lava lamp.
- `ExtractArtworkColor.swift`: Extracts dominant/vibrant color from artwork.
- `MediaPlayerConstants.swift`: Bundle IDs + config for Apple Music, Spotify, Podcasts.

### 🎶 Media Providers
- `MediaPlayerAppProvider.swift`: Chooses the active media app.
- `AppleMusicManager.swift`: Talks to Music using ScriptingBridge.
- `SpotifyManager.swift`: Controls Spotify playback + fetches artwork from URL.
- `PodcastsManager.swift`: Placeholder logic; Podcasts lacks scripting support.

### 🌦️ Weather
- `NotchlyWeather.swift`: Mocked weather module (eventually real API).

---

## Future Roadmap

- **iPhone Connectivity**  
  - Adds interaction between Mac + iPhone when tethered or nearby.

- **Live Activities + Alerts**  
  - Compact alerts in the notch for meetings, music, timers.

- **Customization Options**  
  - Choose what content shows in the notch. Add animation themes.

- **Performance**  
  - Lower CPU/GPU usage when idle. Prioritize energy efficiency.

---

## Getting Started

### Prerequisites
- MacBook (ideally with a notch)
- macOS 14.0+
- Xcode 15.0+

### Installation
```bash
git clone https://github.com/mason-blumling/Notchly.git
cd Notchly
```
Open `Notchly.xcodeproj` in Xcode, build, and run.

---

## Contributing

Issues, pull requests, and stars are all welcome 💫
Please follow the existing Swift/SwiftUI conventions and use modern Apple frameworks.

---

## Thanks

Thanks for supporting Notchly.
This project started as my first app and is becoming something way cooler. ❤️


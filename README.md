# Musicfy

iOS audio player yang streaming dan download audio dari YouTube, dengan equalizer 10-band dan UI modern.

## Features

- 🎵 **Audio Streaming** — Streaming langsung audio-only dari YouTube via [YouTubeKit](https://github.com/alexeichhorn/YouTubeKit)
- 📥 **Download Offline** — Download audio m4a ke device untuk playback offline
- 🎚️ **10-Band Equalizer** — 12 preset (Flat, Bass Boost, Treble Boost, Vocal, Rock, Pop, Jazz, Classical, Electronic, Hip-Hop, Lounge, Bass Reducer) + custom manual adjustment
- 🔍 **Search & Browse** — YouTube Data API v3 untuk search, trending, categories
- 🎨 **Modern UI** — Dark mode, YouTube-style layout, mini player + full player
- 📱 **Background Playback** — Audio tetap jalan saat app di background atau lock screen
- 🎧 **Lock Screen Controls** — Artwork, title, play/pause, next/prev via system controls
- 💾 **SwiftData** — Persistent storage untuk downloaded tracks

## Requirements

- iOS 17.0+
- Xcode 15.3+
- Swift 5.9+

## Installation

### 1. Clone repo

```bash
git clone <repo-url>
cd Musicfy
```

### 2. Open di Xcode

```bash
open Musicfy.xcodeproj
```

Swift Package Manager akan auto-resolve dependency `YouTubeKit`.

### 3. Build & Run

Pilih target iPhone (Simulator atau Physical Device), lalu **Cmd+R**.

## Sideload via KSign/Scarlet

1. Build IPA dari Xcode: **Product → Archive → Distribute App → Development → Export**
2. Install via [KSign](https://github.com/Aniketyadav44/KSign) atau [Scarlet](https://usescarlet.com/) dengan Apple ID gratis

## GitHub Actions

Workflow `.github/workflows/build.yml` akan otomatis build IPA unsigned setiap push ke `main`.

Download artifact dari **Actions** tab di GitHub repo.

## Architecture

```
Musicfy/
├── App/                  # Entry point (MusicfyApp, ContentView)
├── Core/
│   ├── Audio/           # AudioEngine, EQPresets
│   ├── Models/          # Track (SwiftData), TrackInfo, SearchResult
│   ├── YouTube/         # SearchService (YouTube Data API v3)
│   └── Download/        # DownloadManager
└── Features/
    ├── Home/            # Trending, categories
    ├── Search/          # Search view + debouncing
    ├── Player/          # MiniPlayerView, FullPlayerView
    ├── Library/         # Downloaded tracks
    └── Equalizer/       # EQ view dengan 10 sliders vertical
```

## API Key

YouTube Data API v3 key ada di `SearchService.swift`. Quota gratis: **10,000 units/day** — cukup untuk personal use.

Untuk production, buat key sendiri di [Google Cloud Console](https://console.cloud.google.com/) → Enable YouTube Data API v3.

## Tech Stack

- **SwiftUI** — UI framework
- **SwiftData** — Persistence
- **AVFoundation** — `AVAudioEngine` + `AVAudioUnitEQ`
- **YouTubeKit** — YouTube stream extraction
- **YouTube Data API v3** — Search & browse

## License

MIT

## Credits

- [YouTubeKit](https://github.com/alexeichhorn/YouTubeKit) by Alexander Eichhorn

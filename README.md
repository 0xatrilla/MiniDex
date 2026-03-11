
<img width="125" height="125" alt="appicon-iOS-Default-1024x1024@1x" src="https://github.com/user-attachments/assets/77655300-fbd4-4faf-8ed8-7d040bb96529" />

# MiniDex

MiniDex is an iPhone-first SwiftUI companion app for Codex sessions running on your Mac. It connects directly to `codex app-server` over WebSocket, lets you monitor live threads from your phone, and adds mobile controls for approvals, queued prompts, image attachments, plan mode, and repo-aware git actions.

There is no separate Mac bridge app in this repository. The current project state is a native iOS client that talks straight to Codex.

## Current Project State

- App target: `minidex`
- Xcode project: `minidex/minidex.xcodeproj`
- Platform: iOS
- Device family: iPhone
- Deployment target: iOS 26.0
- Bundle identifier: `com.minidex.ios`
- UI stack: SwiftUI
- Transport: WebSocket JSON-RPC to `codex app-server`

Build status verified on March 11, 2026 with:

```sh
xcodebuild -scheme minidex -project minidex/minidex.xcodeproj -destination 'generic/platform=iOS Simulator' build
```

## What MiniDex Can Do Today

- Pair directly with a reachable `ws://` or `wss://` Codex app-server endpoint
- Save the last successful server URL in Keychain and reconnect automatically when possible
- Show onboarding for local-network and Tailscale-based pairing
- Scan QR codes for pairing URLs
- Browse, search, rename, archive, unarchive, and delete threads
- Group threads by project path and keep archived chats accessible
- Stream conversation timelines and keep recent history cached on-device
- Send new turns with optional image attachments from the camera or photo library
- Queue follow-up prompts while a run is active, then flush or steer them later
- Use `@file` fuzzy file search and `$skill` autocomplete in the composer
- Choose runtime model, reasoning effort, and access mode from the app
- Start plan-mode turns when the connected runtime supports collaboration mode
- Approve or decline command/tool approval requests from mobile
- Interrupt active turns
- See context window usage and request context compaction
- Use repo-aware controls for branch switching, pull, commit, push, commit-and-push, PR creation, and discard-to-remote flows
- Preview and apply assistant-scoped patch reverts when an exact diff was captured
- Receive local notifications when a backgrounded run completes

## Requirements

- macOS with Xcode 26.0 and the iOS 26 SDK
- A Codex installation on your Mac with `codex app-server` available
- A network path from your iPhone to your Mac, either:
  - the same local network, or
  - the same Tailscale tailnet

You will also need to grant these iOS permissions if you use the related features:

- Local Network: connect to Codex on your Mac
- Camera: scan pairing QR codes and capture image attachments
- Photos: attach images from the library
- Notifications: background run completion alerts

## Getting Started

Open the project in Xcode:

```sh
open minidex/minidex.xcodeproj
```

Or build from the command line:

```sh
xcodebuild -scheme minidex -project minidex/minidex.xcodeproj -destination 'generic/platform=iOS Simulator' build
```

Run the `minidex` scheme on an iPhone or iOS Simulator.

## Pairing With Codex

1. Start Codex app-server on your Mac:

```sh
codex app-server --listen ws://0.0.0.0:4200
```

2. Get a reachable address for your Mac.

For local Wi-Fi:

```sh
ipconfig getifaddr en0
```

For Tailscale:

```sh
tailscale ip -4
```

3. In MiniDex, either:

- paste a URL like `ws://192.168.1.25:4200`
- paste a URL like `ws://100.x.y.z:4200`
- scan a QR code containing that WebSocket URL

MiniDex also accepts QR payloads that are JSON objects containing one of these keys:

- `serverURL`
- `serverUrl`
- `appServer`
- `url`
- `wsURL`
- `wsUrl`

Once a connection succeeds, the app stores the server URL in Keychain and uses it for reconnect flows.

## Architecture Overview

- `minidex/minidex/MiniDexApp.swift`: app entry point and service wiring
- `minidex/minidex/ContentView.swift`: root navigation shell, onboarding, connection setup, sidebar flow
- `minidex/minidex/Services/`: WebSocket transport, runtime compatibility handling, sync loops, notifications, persistence, git actions, and revert flows
- `minidex/minidex/Views/Turn/`: timeline rendering, composer, attachments, approvals, plan-mode cards, diff rendering, and git toolbar UI
- `minidex/minidex/Views/Sidebar/`: thread search, grouping, archived chats, and navigation
- `minidex/minidex/Models/`: thread, message, runtime, git, and attachment models

## Runtime Compatibility Notes

The app already includes fallbacks for multiple Codex runtime shapes, including:

- `initialize` with and without experimental capabilities
- collaboration mode discovery before enabling plan mode
- modern `sandboxPolicy` and legacy `sandbox` payloads
- approval policy enum fallbacks across server versions
- multiple `model/list`, `skills/list`, and thread payload shapes
- automatic fallback when structured skill input is unsupported

MiniDex works best with a recent Codex runtime, but the client is intentionally defensive about protocol changes.

## Dependencies

Swift Package Manager resolves these packages for the current project:

- [`textual`](https://github.com/gonzalezreal/textual.git) for markdown/text rendering
- [`swiftui-math`](https://github.com/gonzalezreal/swiftui-math)
- [`swift-concurrency-extras`](https://github.com/pointfreeco/swift-concurrency-extras)

## Known Gaps

- The Xcode project still defines `minidexTests` and `minidexUITests`, but there are no checked-in test sources in the repository right now.
- The project is currently iPhone-only.
- This repository does not ship a standalone Mac companion app; the supported workflow is direct connection to `codex app-server`.

# Architecture & Platform Decisions

## Summary of permissions

| Permission / entitlement | Required? |
|---|---|
| App Sandbox (`com.apple.security.app-sandbox`) | **Yes** — the only entitlement |
| Screen Recording | No |
| Accessibility | No |
| Input Monitoring | No |
| Network (client/server) | No |
| File access (user-selected, downloads, …) | No |
| "Paste from Other Apps" (macOS 26 pasteboard privacy) | System prompt on first hotkey use — see below |

## 1. Global hotkey: Carbon `RegisterEventHotKey`

- **Works in the App Sandbox** and needs no Accessibility or Input Monitoring permission. The window server delivers only the registered key combination to Airink; we never see other keystrokes. (`NSEvent.addGlobalMonitorForEvents` and `CGEventTap` would need permissions, so they are not used.)
- It is a Carbon API but still supported, with no modern replacement for apps outside the App Store's App Shortcuts model. It is wrapped in `HotKeyCenter` (~80 lines).
- We register with `kEventHotKeyExclusive`. **Conflict detection is best-effort.** Carbon returns `eventHotKeyExistsErr` only when another process holds the same combination exclusively. If the combination clashes with a system shortcut (System Settings › Keyboard › Keyboard Shortcuts) or with another app that didn't register exclusively, the OS doesn't report it. In that case the first registrant usually wins without any warning. Airink shows any reported failure as an alert at launch, in the menu and in Settings.
- **Default `⌘⇧A` overrides app-level shortcuts** that use the same combination while Airink runs, e.g. Finder's *Go › Applications*. That's inherent to global hotkeys, and the shortcut can be changed in Settings.
- The shortcut recorder uses `NSEvent.addLocalMonitorForEvents`, which sees only keys sent to Airink's own Settings window, so it needs no permission. The global hotkey is unregistered while recording, so the current combination can be re-recorded.

## 2. Clipboard access and macOS pasteboard privacy

- Sandboxed apps can read and write `NSPasteboard.general` without an entitlement.
- Since macOS 15.4/26, reading the general pasteboard *programmatically* (not from a user ⌘V) shows a system prompt, **"Airink would like to paste from …"**. The hotkey counts as programmatic, so users see the prompt the first time. Choosing *Always Allow* stores the choice under System Settings › Privacy & Security › Paste from Other Apps.
- Airink reads the pasteboard **only** when the hotkey (or the menu item) is triggered. It first checks `availableType(from:)`, which reads metadata only and doesn't prompt, so an empty or text-only clipboard never shows the prompt.
- If the user chose *Always Deny* (`accessBehavior == .alwaysDeny`), Airink explains where to change it.
- Writing to the pasteboard needs no permission. Airink writes **PNG** only, with DPI metadata so Retina images paste at the right size. TIFF is skipped because an uncompressed copy of a 5K screenshot would add tens of MB for no practical gain.

## 3. App shape

- `LSUIElement = YES`: no Dock icon, no app switcher entry. A SwiftUI `MenuBarExtra` provides the menu, and a SwiftUI `Settings` scene provides preferences.
- The **editor is AppKit** (`NSWindow` + `NSView`). Showing a window from a hotkey, giving it key focus, handling raw key events (Return/Esc/⌘C while a text field may be editing), and returning focus all need direct window control. SwiftUI is used for the toolbar inside it (`NSHostingView`).
- **Focus return:** after closing, `NSApp.hide(nil)` gives activation back to the previously active app. That's more reliable than reactivating a remembered `NSRunningApplication`, which cooperative activation (macOS 14+) can refuse.
- The window uses `.moveToActiveSpace` and `.fullScreenAuxiliary`, so it appears on the current Space, including over full-screen apps.

## 4. Rendering & coordinates

- All annotation geometry is stored in **image pixel space**. The canvas maps view points ↔ pixels with a single scale factor, so a downscaled Retina screenshot still exports at full resolution.
- `Renderer` (pure Core Graphics/Core Text, `nonisolated`) draws both the on-screen overlay and the exported image, so what you see is what gets copied.
- Stroke widths and font sizes are defined in points and multiplied by the image's point scale, which comes from its DPI (144 DPI → 2×).
- The base image is set as a **layer's contents** and composited by the GPU. Only the transparent annotation overlay is redrawn during drags, which keeps editing smooth on large Retina screenshots.
- Output keeps the source image's color space (e.g. Display P3 screenshots).

## 5. Memory & idle behavior

- Idle work: none. No timers, no polling, no observers. The only thing installed is the Carbon hotkey handler.
- Each editing session creates an `AnnotationDocument` (image + annotations + `UndoManager`) owned by `EditorController`. On close, the controller drops the window, canvas and document, and clears the undo stack, so the image buffers are freed.
- Measured on a local build: **0.0 % CPU idle, ~19 MB footprint.**

## 6. Concurrency

- Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY = complete`, and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode 26's "approachable concurrency"). All UI code is main-actor isolated by default. Pure value types and the renderer are explicitly `nonisolated`.
- The Carbon callback is a C function pointer and runs on the main thread. It enters main-actor code with `MainActor.assumeIsolated`.

## 7. Undo

- One `UndoManager` per document, with `groupsByEvent = false` and explicit grouping: one undo step per annotation, independent of run-loop timing (which also keeps tests deterministic).
- Text typed in an active text field uses the field editor's own undo until it's committed.

## 8. Launch at login

`SMAppService.mainApp` is sandbox-compatible and needs no helper app. It works best when Airink is in `/Applications`. macOS may require approval in System Settings › General › Login Items.

## 9. Dependencies

None. Frameworks used: AppKit, SwiftUI, Carbon (HIToolbox, hotkey only), ImageIO, Core Text, ServiceManagement.

## 10. Distribution

- Releases are DMGs built by `scripts/make-dmg.sh`: Universal (arm64 + x86_64), ad-hoc signed with the hardened runtime, and attached to GitHub Releases.
- **Not notarized.** That needs a Developer ID certificate (Apple Developer Program). Gatekeeper blocks the first launch until the user clicks *Open Anyway*, as documented in the README.
- An ad-hoc signature identifies only one exact build. Per-app system state can therefore reset when a user updates to a new version: the "Paste from Other Apps" choice and the Login Item. Moving to Developer ID signing fixes both, with no code changes.

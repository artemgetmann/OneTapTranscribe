# OneTapTranscribe Design System

Reference document for maintaining visual consistency across the app. All design decisions, color values, component specs, and principles live here.

## Design Philosophy

**Apple Liquid Glass aesthetic** — frosted depth layers, refractive light effects, fluid morphing. The app is a single-purpose tool: tap once to record, get a transcript. The UI reflects that — one hero element, zero clutter, speed IS the design.

**Core principles:**
- One tap target (the glass orb) dominates the screen
- No scroll views, no card lists, no unnecessary chrome
- Snappy transitions (0.3s springs) — nothing floaty or slow
- Adaptive light/dark mode with full material system support

## Color System

### Iridescent Blue-to-Violet Gradient

The signature palette shifts from cornflower blue to orchid violet, creating an iridescent color-changing effect.

| Token | Role | Value | Hex (approx) |
|-------|------|-------|---------------|
| `accentBlue` | Gradient start (blue end) | `rgb(0.400, 0.494, 0.976)` | `#667EF9` |
| `accentViolet` | Gradient end (violet end) | `rgb(0.769, 0.357, 0.988)` | `#C45BFC` |
| `accent` | Flat midpoint for single-color contexts | `rgb(0.604, 0.424, 0.973)` | `#9A6CF8` |
| `accentGradient` | Primary gradient (topLeading → bottomTrailing) | `accentBlue → accentViolet` | — |

### Where Each Token Is Used

- **`accentGradient`**: Mic icon, stop icon, copy button fill, status badge dot, gear icon tint, recording tint overlay, Dynamic Island buttons/dots/waveform bars
- **`accent`** (flat): ProgressView tint, SettingsSheet tint, Control Center widget tint (API limitation — `.tint()` only accepts `Color`)
- **`accentBlue`**: Ambient blob (top-left), ambient blob (bottom), pulse glow secondary
- **`accentViolet`**: Ambient blob (right), pulse glow primary (recording breathing aura)

### Background Gradients

**Light mode** (3-stop, topLeading → bottomTrailing):
```
rgb(0.94, 0.95, 1.0) → rgb(0.97, 0.95, 1.0) → rgb(0.99, 0.98, 1.0)
```
Subtle blue wash top-left fading through lavender to near-white.

**Dark mode** (3-stop, topLeading → bottomTrailing):
```
rgb(0.05, 0.04, 0.14) → rgb(0.08, 0.03, 0.12) → rgb(0.03, 0.02, 0.08)
```
Deep indigo-to-purple fading to near-black.

### Ambient Blobs

Three blurred circles create the iridescent color-shifting background:

| Blob | Color | Diameter | Position | Opacity (light/dark) |
|------|-------|----------|----------|---------------------|
| 1 | `accentBlue` | 300pt | (-100, -280) | 0.25 / 0.18 |
| 2 | `accentViolet` | 340pt | (160, -150) | 0.25 / 0.18 |
| 3 | `accentBlue` | 200pt | (120, 300) | 0.125 / 0.09 |

All blobs use `blur(radius: 50)`.

## Glass Material System

Three tiers of glass modifiers, each using SwiftUI materials with refractive gradient borders:

### `.liquidGlassOrb(diameter:)`
- Primary hero element (the record button)
- Default: 180pt diameter
- Background: `.ultraThinMaterial` (dark) / `.thinMaterial` (light)
- Border: 1pt `LinearGradient` stroke (white 18%→4% dark, 70%→15% light)
- Inner convex: `RadialGradient` overlay (clear center → black edge)
- Drop shadow: 30pt radius, 15pt y-offset

### `.liquidGlassCard(cornerRadius:)`
- Used for transcript overlay, status badge
- Default: 24pt corner radius (16pt for chips like status badge)
- Same material + border treatment as orb but with `RoundedRectangle`
- Drop shadow: 20pt radius, 10pt y-offset

### `.liquidGlassChip()`
- Small circular elements (gear button, dismiss button)
- `.ultraThinMaterial` in `Circle()`
- Subtle 0.5pt white border

## Component Architecture

```
ContentView.swift (121 lines — thin state router)
├── Theme/
│   ├── LiquidGlassTheme.swift    — colors, gradients, constants, AppVisualState enum
│   ├── GlassModifiers.swift       — glass card/chip/orb ViewModifiers
│   └── PulseEffect.swift          — breathing glow animation modifier
├── Components/
│   ├── GlassOrbButton.swift       — hero 180pt record/stop orb
│   ├── StatusBadge.swift          — floating timer chip during recording
│   ├── TranscriptCard.swift       — slide-up glass overlay with copy
│   └── SettingsSheet.swift        — extracted settings form
```

### GlassOrbButton States

| State | Icon | Effect | Overlay |
|-------|------|--------|---------|
| Idle | `mic.fill` | None | None |
| Recording | `stop.fill` | `.pulseGlow(isActive: true)` | Gradient tint 10% |
| Uploading | `ProgressView` spinner | None | None |

- Icon uses `accentGradient` foreground style
- iOS 17: `.contentTransition(.symbolEffect(.replace))` for icon morphing
- iOS 16 fallback: `.id()` swap with `.transition(.opacity)`
- Press feedback: `OrbPressStyle` scales to 0.96

### Pulse Glow (Recording Indicator)

- Color: `accentViolet` (the purple end, for contrast)
- Max radius: 40pt
- Animation: 1.8s `easeInOut`, repeating, autoreverses
- Shadow opacity oscillates 0.2 → 0.5
- Shadow radius oscillates 60% → 100% of max

## Widget Theming

Widget extensions can't share Swift files with the app target, so colors are defined as literals.

### Dynamic Island / Lock Screen (`RecordingLiveActivityWidget`)

- `brandGradient`: `LinearGradient` matching `accentBlue → accentViolet`
- Used on: stop button capsule, indicator dots, waveform bars
- Waveform: 11 animated bars, `sin()` phase-shifted, 3pt wide capsules

### Control Center (`OneTapRecordControlWidget`)

- Uses flat `accent` midpoint via `.tint()` (gradient not supported by `ControlWidget` API)

## Animation Timings

| Token | Value | Usage |
|-------|-------|-------|
| `stateTransition` | 0.3s spring | State changes (idle ↔ recording ↔ uploading) |
| `pulseFrequency` | 1.8s easeInOut | Recording breathing glow |
| `cardSlide` | 0.35s spring | Transcript card slide-up |

## Layout Constants

| Token | Value | Usage |
|-------|-------|-------|
| `orbDiameter` | 180pt | Glass orb button |
| `orbRecordingGlowRadius` | 40pt | Max pulse glow spread |
| `cardCornerRadius` | 24pt | Transcript card |
| `chipCornerRadius` | 16pt | Status badge, small cards |

## AccentColor Asset

The Xcode asset catalog `AccentColor` is set to the flat midpoint:
```json
{ "red": 0.604, "green": 0.424, "blue": 0.973 }
```
This is used system-wide by SwiftUI for default tints, navigation bars, etc.

## Design Decisions Log

1. **Gradient over flat color**: The original flat `#8B5CF6` purple felt lifeless. Shifted to a blue→violet gradient inspired by modern app icons that use iridescent color-shifting.
2. **Three ambient blobs (not two)**: Two blobs created a simple diagonal. Adding a third at the bottom creates a triangular color field that feels more natural and dimensional.
3. **No ScrollView**: The app's single-purpose nature means everything fits on one screen. Scroll would add unnecessary interaction complexity.
4. **Orb over button**: A large glass orb is a more interesting tap target than a standard button. It reinforces the "one tap" brand.
5. **Notification skip in simulator**: `prepareNotifications()` triggers a system dialog that blocks UI testing in the simulator. If needed, wrap in `#if !targetEnvironment(simulator)` temporarily for screenshot sessions.

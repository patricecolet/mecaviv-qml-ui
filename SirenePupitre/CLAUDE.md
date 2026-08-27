# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Qt6/QML application ("pupitre") that visualizes real-time musical and mechanical data for a
mechanically-controlled siren. It's one local interface in the larger `mecaviv-qml-ui` system:

```
Console (SirenConsole) → Pupitres (SirenePupitre) → PureData (execution) → Physical sirens
     ↑                        ↑                           ↑                    ↑
  Max priority          Local control              MIDI routing         Instruments
                                                    + virtual VSTs
```

- **Console**: max priority, can take control of any pupitre (`CONSOLE_CONNECT`/`CONSOLE_DISCONNECT`).
- **Pupitre** (this app): autonomous by default, or remote-controlled by the console.
- **PureData**: executes, routes MIDI, talks to physical/virtual sirens.

**Deployment target is WebAssembly** (see memory `project_sirenmanager_target`, same constraint applies
here). Desktop Qt builds exist only for faster local development — don't add desktop-only APIs.

## Build & run

Only the WebAssembly build path is maintained (no desktop build script currently).

```bash
./scripts/build.sh web              # configure+compile via qt-cmake (wasm_singlethread), copy artifacts into webfiles/
./scripts/build.sh clean            # remove build/ and webfiles/build/
./scripts/dev.sh web                # build + start server + open Chrome
./scripts/dev.sh server             # start server + open Chrome (skip build)
./scripts/start-server.sh [PORT]    # just the Node server (default port 8000)
./scripts/dev-with-logs.sh          # dev mode with browser console logs surfaced
```

Requires Qt6 for WebAssembly installed at `$HOME/Qt/6.10.0/wasm_singlethread` (qt-cmake), CMake 3.16+,
Node.js. There is no automated test suite — verification is manual (build, load in browser, exercise
the feature).

Raspberry Pi 5 deployment (production target machine):
```bash
./scripts/start-raspberry.sh start|server|puredata|browser|stop
./scripts/restart-servers.sh
```

3D mesh assets are authored as `.obj` and converted with Qt's `balsam` tool:
```bash
./scripts/convert-mesh.sh <file.obj> <name.mesh>   # handles balsam's meshes/ subfolder quirk
./scripts/convert-clefs.sh                          # regenerates TrebleKey.mesh / BassKey.mesh
```

## Architecture

### Entry point & module structure
`main.cpp` loads `qrc:/QML/Main.qml` via `QQmlApplicationEngine`. `data.qrc` / `qt_add_qml_module`
(CMakeLists.txt) bundle QML, fonts, and meshes into the binary — new QML files or assets must be
registered there to be picked up by the wasm build.

`QML/Main.qml` is the root `Window` and owns all top-level controllers as children:
`ConfigController`, `SirenController`, `EncoderController`, `WebSocketController`, `NavigationManager`.
App-wide state (`isAdminMode`, `gameMode`, `isGamePlaying`, `uiControlsEnabled`, etc.) lives as
properties directly on `Main.qml` and is passed down — there's no separate state-management layer.

### Configuration: two sources, one priority order
- `config.js` (repo root): fallback config loaded at startup, plain JS object (`configData`).
- `config.json` in PureData: the authoritative config, pushed over WebSocket as `CONFIG_FULL`.
- Priority: **PureData always wins** once it responds. Startup sequence: `ConfigController` loads
  `config.js` → `WebSocketController` connects → pupitre sends `REQUEST_CONFIG` → if PureData replies
  with `CONFIG_FULL`, that replaces `config.js`; otherwise `config.js` stays active.
- Local UI edits are pushed back to PureData as `PARAM_CHANGED`; PureData can push individual
  `PARAM_UPDATE` messages at any path. A `source: "console"` tag on incoming updates prevents
  re-emitting a message PureData (or the console) just sent — don't strip this without checking for
  feedback loops.
- Numeric `0`/`1` on any `"visible"`-suffixed field are auto-coerced to booleans in
  `ConfigController.setValueAtPath()` (PureData has no native bool).

### WebSocket wire protocol: binary, not JSON
All hot-path messages (60–100 Hz) are binary, first byte = message type. **Never add a new hot-path
message as JSON** — that was the old format and it's kept only for backward compat, at ~40x the size
and JSON.parse cost. Full field-level layouts live in `PROTOCOLE_UDP_SIMPLE.md`,
`STRUCTURE_BINAIRE_0x02.md`, `STRUCTURE_BINAIRE_0x06.md`, and `CHANGELOG_BINARY_PROTOCOL.md` — read
those before touching `WebSocketController.qml`'s decode logic. Summary of types:

| Type | Meaning | Size | Notes |
|------|---------|------|-------|
| `0x00` CONFIG | full JSON config | variable | see config section above |
| `0x01` POSITION | playback bar/beat | 10 B | sent *at* playback time (monitoring), 50-100 Hz |
| `0x02` CONTROLLERS | all physical controller states | 16-18 B | wheel, pads, joystick, fader, pedal, buttons, encoder |
| `0x03` MIDI_NOTE_VOLANT | wheel position as MIDI note | 5 B | moves the staff cursor |
| `0x04` MIDI_NOTE_DURATION | sequence note + duration | 5 B | sent *ahead* of playback by `midiDelayMs` so falling notes land on time — game mode only |
| `0x05` CONTROL_CHANGE | sequence MIDI CC | 3 B | vibrato/tremolo/envelope — game mode only |
| `0x06` ENCODER_NAVIGATION | encoder value + pressed | 3 B | **UI navigation only** — deliberately separate from the encoder bytes inside `0x02`, which are for the visual Controllers panel |

Key distinction to preserve when editing: `0x02`/`0x06` are physical-controller telemetry for display;
`0x04`/`0x05` are sequenced MIDI for game mode; `0x01` is playback position for monitoring. Don't merge
these paths even when the data looks similar.

### Directory map (QML/)
- `components/` — visual components (`SirenDisplay`, `ControllersPanel`, `StudioView`,
  `ambitus/` musical-staff rendering, `indicators/` per-controller widgets).
- `controllers/` — logic-only QML: `ConfigController`, `SirenController`, `WebSocketController`,
  `EncoderController`, `NavigationManager`.
- `admin/` — password-gated admin panel (`visibility/`, `advanced/` sub-sections) for toggling
  component visibility, colors, sizes, per-siren ambitus/transposition/fretted-mode.
- `game/` — "Guitar Hero"-style game mode (falling notes synced to `0x04`/`0x05`); see
  `QML/game/README.md` and `QML/game/BINARY_FORMAT_EXAMPLES.md` for the fall-timing model.
- `game/microtonal/` — microtonal variant of game mode (active development on
  `feature/microtonal-mode`): `MicrotonalViewModel`, `MicrotonalMath.js`, pitch ribbon/timeline
  rendering, cent-accurate readouts, distinct from the diatonic staff used elsewhere.
- `utils/` — reusable primitives: LED-style 3D displays (`LEDText3D`, `DigitLED3D`, `NumberDisplay3D`),
  `Clef3D`/`Clef2D`/`Clef2DPath` (3D mesh vs. font-based clef rendering — 2D variants are lighter/faster
  for overlay use), `MusicUtils.qml` (MIDI↔frequency↔RPM math), `meshes/` (`.mesh` + source `.obj`).
- `pages/` — standalone test pages (e.g. `Test2D.qml`), not part of the main app flow.

### Musical positioning model
Staff Y-position uses **diatonic** degrees (Do-Ré-Mi-Fa-Sol-La-Si = 7 steps/octave), not chromatic
semitones — `positionDiatonique = octave*7 + noteDiatonique`. Treble clef reference is Sol4 (MIDI 67,
2nd line); bass clef reference is Fa3 (MIDI 53, 4th line). Frequency/RPM math (`MusicUtils.qml`):
`freq = 440 * 2^((note + transposition*12 - 69)/12)`, `RPM = freq*60/outputCount`. Note-range clamping
differs by mode: `restricted` caps at `restrictedMax`, `admin` allows the full siren `ambitus`.

### webfiles/
Contains the wasm build output plus a small Node dev server (`server.js`) exposing a MIDI file-listing
API (`api-midi.js`, `api-midi-notes.js`) used by the song selector in game mode. `midifiles/` (repo
root) is the MIDI library organized by composer (`louette/`, `patwave/`, `covers/`) — used both as test
content and concert repertoire.

## Working notes

- This app is one of several sibling projects under `mecaviv-qml-ui` (`SirenManager`, `SirenConsole`,
  `sirenRouter`, `pedalierSirenium`); the git repo root is one level up from `SirenePupitre/`.
- If a change here touches the firmware-facing MIDI/UDP path shared with `SirenManager`, the same
  physical-machine constraints apply: MIDI is cached at module load, so content changes need a reboot
  on every machine, and the `ASKSYNCHRO`/`NEWLIST` UDP commands have specific hot-reload semantics.
- If sirens oscillate, rule out two simultaneous control clients (e.g. console + pupitre both
  connected at once) before debugging QML controller logic here.

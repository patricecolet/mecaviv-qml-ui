# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project context

PedalierSirenium is one of several Qt6/QML applications in the `mecaviv-qml-ui` monorepo (parent at `..`). It is the 3D pedalier interface: 8 pedals × 7 sirens, rendered as a Quick3D scene, driven entirely over WebSocket. Siblings are `SirenePupitre` (per-pupitre visualizer), `SirenConsole` (central console), `SirenManager` (control panel / UDP+SSH app), and `sirenRouter` (Node.js monitoring). Cross-project protocol questions belong in `../docs/COMMUNICATION.md` and `../docs/MIDI_WEBSOCKET_API.md`.

**PureData is the source of truth at runtime.** This app has no MIDI stack of its own — `qmlmidi` was abandoned for WASM compatibility, and the Web MIDI API is only probed by an injected script in the host page (informational, not wired to QML). PD connects to `ws://localhost:10000` and pushes everything. The app never opens a MIDI port.

The final delivery target is **WebAssembly in a browser**; desktop builds exist only for dev speed. Anything added here must survive WASM (no filesystem, no local sockets, no native MIDI).

## Build

Both build paths share `QtFiles/CMakeLists.txt`:

```bash
# WebAssembly (primary path — builds, copies to webfiles/, starts node, opens Chrome)
./scripts/build_run_web.sh                 # full clean rebuild
./scripts/build_run_web.sh --no-clean --no-open   # incremental, no browser

# From monorepo root
cmake --preset=default && cmake --build build --parallel   # desktop
cmake --preset=wasm                                        # WASM
```

`build_run_web.sh` hardcodes `$HOME/Qt/6.10.0/wasm_singlethread/bin/qt-cmake`. It copies `qmlwebsocketserver.{html,js,wasm}`, `qtloader.js`, and `qml/qmlwebsocketserver/config.js` into `webfiles/`, then rsyncs the QML module dir.

**`QtFiles/CMakeLists.txt` does not link `Qt6::Quick3D`, so the target currently fails to link** — `main.cpp` calls `QQuick3D::idealSurfaceFormat()` for the 30 FPS `setSwapInterval(2)` config, and the link dies on `Undefined symbols: QQuick3D::idealSurfaceFormat(int)` (verified on a standalone desktop build; the root-level build hits the same thing, since the root `find_package` includes Quick3D but the subdirectory target never links it). Fix by adding `Quick3D` to the `find_package` COMPONENTS and `Qt6::Quick3D` to `target_link_libraries` — don't work around it by deleting the Quick3D include, the whole UI is a `View3D`.

`webfiles/*.wasm` is gitignored (~36 MB, distributed via Google Drive). `./scripts/download_wasm.sh` fetches it. Everything else in `webfiles/` except `server.js`, `config.js`, and `package.json` is a build artifact — don't hand-edit.

## Run

```bash
cd webfiles && npm install && node server.js   # port 8010
```

The Node server is not optional for browser runs: it sets the **COOP/COEP headers Qt WASM requires**, and it injects a `<script>` into the served HTML that mirrors `console.*` and window errors back to `POST /log`. That is the main debugging channel for WASM:

```bash
tail -n 120 /tmp/webfiles_server.log | sed -e 's/\x1b\[[0-9;]*m//g'
curl -s http://localhost:8010/logs | jq .        # also /logs/stream (SSE)
```

Serving `qmlwebsocketserver.html` as a plain static file skips the injection and the COOP/COEP headers — the page won't boot correctly.

`scripts/start.pedalier.sh` is the on-device (Raspberry Pi) boot sequence: reaper → `pd -nogui MidiToSiren.pd` → rtpmidid → node → Chromium kiosk → `wvkbd-mobintl`. Its paths are absolute and machine-specific.

## Architecture

### Hybrid WebSocket transport (`ws://localhost:10000`)

One socket, three asymmetric channels — this asymmetry is the thing to internalize:

- **Inbound text** = JSON application state (loops, scenes, presets, clock, `sirenPings`). Handled in `WebSocketController.onTextMessageReceived`, dispatched by `json.device` (`SIREN_LOOPER` / `SIREN_PEDALS` / `LOOPER_SCENES`) into `batchReceived(batchType, data)`.
- **Inbound binary** = raw MIDI, 1 or 3 bytes, forwarded straight to `MidiMonitorController.applyExternalMidiBytes`. This is the hot path — it is deliberately log-free (per-event logs are TRACE only, with a 1000 ms aggregate summary instead). Keep it cheap.
- **Outbound** = JSON, but sent via **`socket.sendBinaryMessage(jsonString)`**, marked `@CRITICAL: Ne pas changer - binaire requis` in `WebSocketController.sendMessage`. PD expects binary frames. Switching to `sendTextMessage` silently breaks every outgoing command.

1-byte frames (clock `0xF8`, start/continue/stop `0xFA`/`0xFB`/`0xFC`) are currently counted and dropped in `applyExternalMidiBytes`; only 3-byte channel messages (Note On/Off, CC, Pitch Bend) update state. Clock-driven quantization is unimplemented (README Phase 4).

### Signal chain

`main.qml` wires everything by hand; there are no QML singletons and no C++ types registered — `main.cpp` is a stock `QQmlApplicationEngine` loading `qrc:/qml/qmlwebsocketserver/main.qml`. Controllers are plain `Item`/`QtObject` instances that receive their collaborators as properties (`logger`, `webSocketController`, …), so a missing assignment fails silently at runtime rather than at compile time.

```
WebSocket ─┬─ text ──→ WebSocketController ──→ batchReceived ──→ MessageRouter ──→ SirenController / BeatController
           │                                                                      PedalConfigController / SceneManager / TempoControl
           └─ binary ─→ MidiMonitorController ──→ midiDataChanged ──→ SirenView ──→ SirenColumn.applyMidi
```

`MessageParser`'s route-registration system (`registerRoute` / `createRouteGroup`, set up in `WebSocketController.setupMessageRoutes`) is largely **vestigial** — the text handler dispatches directly on `json.device` instead, and `MessageRouter.routePathMessage` only logs. Add new message types to the `onTextMessageReceived` dispatch and `MessageRouter.routeBatch`, not to the parser routes.

### MIDI → siren fan-out

Every `SirenColumn` listens to the *same* `midiDataChanged` signal and self-filters: `if (channel !== (sphereId - 1)) return;` (`SirenColumn.qml:283`). So **MIDI channel 0 drives S1 … channel 6 drives S7**, and the `channel` field in `sirenSpec` must agree with `sphereId - 1` or a siren goes deaf.

### sirenSpec: edit the `.js`, not the `.json`

`sirenSpec.json` and `sirenSpec.js` hold the same data (per-siren clef, ambitus, transpose, channel, color; `meta.bendBits: 13`, `meta.bendCenter: 4096`), both are in `data.qrc`, **but only `sirenSpec.js` is read** — `SirenSpecProvider` imports it as a JS module because JSON fetch is fragile under WASM. The `.json` is dead weight kept for documentation; changing it alone has no effect. A spec can also be pushed at runtime via `SirenSpecProvider.applySpecFromWs`.

Note the bend is **13-bit, centered on 4096** (not standard MIDI 14-bit/8192) — but `MidiMonitorController` decodes incoming pitch bend as standard `(data2 << 7) | data1` and defaults `bend` to 8192. Reconcile carefully before trusting bend maths.

### Config

`QtFiles/qml/qmlwebsocketserver/config.js` is the single source for the WebSocket URL, controller definitions (min/max/default/label/color), display order, and section grouping. It is imported by QML *and* `module.exports`-ed for Node. `webfiles/config.js` is a build-script copy — edit the QtFiles one.

The real matrix is **8 pedals × 7 sirens × 8 controllers = 448** values (`volume, vibratoSpeed, vibratoDepth, tremoloSpeed, tremoloDepth, attack, release, voice`). The README's "504 / 9 controllers" is stale; `config.js` wins. All are ±100 % modulation except `voice` (±12 semitones).

## Gotchas

- **`data.qrc` is manual.** New QML/JS/shader/icon files are not auto-discovered; add a `<file>` entry or you get a runtime "module not installed"/blank view. `data.qrc` also reaches outside the project for shared fonts (`../../fonts/`).
- **Logging is off by default.** In `Logger.qml` every category defaults to level 0 (OFF) except `SCENES` and `MIDI` (INFO) — so a new `logger.debug(...)` prints nothing until the category is raised (F12 → Debug tab, or `logger.setAllCategories(4)`). An *unknown* category name silently defaults to INFO, which is why ad-hoc categories like `SYSTEM`/`MONITORING` appear to work.
- **Use the convenience methods** (`logger.info/debug/warn/error/trace(category, …)`), not `logger.log(...)`. `log()` takes `(level, category, …)` and some existing callers pass `("WEBSOCKET", "INFO", …)` reversed — those lines don't log what they claim.
- **Two live sources of doc rot.** `README.md` documents `GET /api/temperature` and `/api/system-info` on `webfiles/server.js`; **those endpoints do not exist there** — yet `SystemInfoReader.qml` calls `http://192.168.1.21:8010/api/system-info` against a hardcoded Pi IP. System-info monitoring only works against some other server. `docs/MIDI_CONFIGURATION.md` describes a Debug Panel "MIDI" tab for IAC/VirMIDI port selection that was removed as obsolete under WASM (`DebugPanel.qml:202`).
- The Debug Panel (F12, or the gear button top-left) has three tabs: Debug / Monitoring / Performance. It hides the `View3D` while open (`visible: !debugPanelVisible`).
- Frame rate is intentionally capped at ~30 FPS via `setSwapInterval(2)` in `main.cpp`.

## Conventions

Code, comments, commit messages, and user-facing strings are **French**; match that in adjacent code. Emoji-prefixed log messages are the house style (`logger.info("PRESET", "✅ Preset chargé")`).

The working tree often spans sibling projects — confirm scope with the user before committing across project boundaries.

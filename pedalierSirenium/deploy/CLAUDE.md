<!-- Chargé seulement quand Claude travaille sous deploy/ — déplacé depuis le CLAUDE.md
     racine pour ne plus occuper le contexte de chaque session. -->

# Déploiement du pédalier

`deploy/pedalier-deploy.sh` (Mac) drives `deploy/pedalier-ctl.sh` (Pi, `sirenateur@192.168.1.21`) over SSH — see `deploy/README.md`. The Pi pulls code from git itself; the Mac only rsyncs the Qt build artifacts (the 40 MB wasm is gitignored). Same command installs from scratch and updates: every phase self-skips when nothing changed, and `--dry-run` simulates on both sides.

On-device the pedalier runs under **systemd `--user`** (`pedalier.target`: rtpmidid → `pd -nogui pedalier.pd` → node → ALSA wiring, the last one replayed by a 60 s timer because RTP ports appear late), with `enable-linger` so the backend boots without a graphical session. The Chromium kiosk is a separate XDG autostart entry (`~/.config/autostart/pedalier-kiosk.desktop`) — never `~/.config/labwc/autostart`, which would replace the Pi's system autostart.

`scripts/start.pedalier.sh` is now a deprecation stub, `scripts/testServerOnRasp.sh` is gone (`pedalier-deploy.sh build` replaces it). The Pi runs **Pd 0.55.2 from `/usr/local`** (Debian's 0.53 stays in `/usr/bin/pd` as a one-line fallback). `pdjson` needs the flat link `~/pd-externals/pdjson.pd_lua`: no Pd version applies the folder convention to `.pd_lua`.

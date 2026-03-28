-- @description Mecaviv — export conductor-cues.json (toutes les pistes MIDI = sirènes)
-- @version 2.8
-- @author mecaviv-qml-ui
-- @about
--   Parcourt **toutes** les pistes du projet : consignes agrégées, ordre temps projet (tick global).
--   **sirenTrackIndex** = canal MIDI de la note (**1–16**), pas l’index de piste Reaper. **sirenTrackName** = nom de piste.
--   Pitch bend → hauteur / pente glissando ; vélocité → volet. Routage sirène → pupitre : config / metadata.
--   Schéma : docs/CONDUCTOR_CUES_PROTOCOL.md

-- Affiche dans la console Reaper (View → Show console) le détail gliss par cue.
-- Mettre à false une fois le diagnostic terminé.
local GLISS_DEBUG = true
-- nil = toutes les cues ; sinon n’affiche que les n premières (évite de saturer).
local GLISS_DEBUG_MAX_CUES = nil

local CONFIG = {
  pitch_bend_range_semitones = 2.0,
  gliss = {
    epsilon_cents_per_quarter = 0.25,
    very_fast_at = 200,
    fast_at = 70,
    -- slow_at : seuil c/noire entre glissSpeed 4 (très lent) et 3 (lent) ; med_at non utilisé pour le mapping.
    med_at = 25,
    slow_at = 8,
    stable_epsilon_cents = 2.0,     -- tolérance de plateau
    stable_min_quarters = 0.125,    -- durée min d'un état stable (en noires)
    transition_min_delta_cents = 4.0, -- évite de traiter du jitter comme gliss
    -- Fenêtre avant la note : si l'écart max des bends (cents) ≤ seuil → pas de gliss (instant).
    -- Fenêtre courte : éviter de confondre avec un gliss très lent sur plusieurs mesures.
    flat_lookback_quarters = 2.0,
    flat_max_spread_cents = 3.0,
    -- Le fallback ne regarde que les bends dans cette fenêtre (évite une pente fantôme avec un vieux bend).
    fallback_max_quarters = 4.0,
  },
}

local function pitch_bend_14_to_cents(bend14, range_sem)
  range_sem = range_sem or 2.0
  local n = (bend14 - 8192) / 8192
  return n * range_sem * 100.0
end

local function midi_to_hz(midi_float)
  -- Pas de math.pow : certaines sandboxes Reaper n’exposent pas math.pow ; utiliser ^ .
  return 440.0 * (2 ^ ((midi_float - 69.0) / 12.0))
end

local function esc_json_str(s)
  if not s then return "" end
  s = tostring(s)
  s = s:gsub("\\", "\\\\")
  s = s:gsub('"', '\\"')
  s = s:gsub("\r", "\\r")
  s = s:gsub("\n", "\\n")
  return s
end

--- Reaper MIDI_GetNote : canal 0–15 → identifiant sirène **1–16** (standard MIDI).
local function midi_channel_to_siren_index(chan)
  local c = chan
  if type(c) ~= "number" then
    c = 0
  end
  c = math.floor(c + 0.5)
  if c < 0 then
    c = 0
  end
  if c > 15 then
    c = 15
  end
  return c + 1
end

local function default_json_export_path()
  local _, projfn = reaper.EnumProjects(-1)
  if projfn and projfn ~= "" then
    return projfn:gsub("%.rpp$", "") .. "_conductor-cues.json"
  end
  local base = reaper.GetProjectPath("") or ""
  if base ~= "" and not base:match("[/\\]$") then
    base = base .. "/"
  end
  return base .. "conductor-cues.json"
end

local function project_title_for_metadata(outfn)
  if outfn and outfn ~= "" then
    local base = outfn:match("([^/\\]+)$") or outfn
    base = base:gsub("%.json$", "")
    if base ~= "" then
      return base
    end
  end
  local _, projfn = reaper.EnumProjects(-1)
  local meta_title = "Projet Reaper"
  if projfn and projfn ~= "" then
    meta_title = projfn:match("([^/\\]+)$") or projfn
    meta_title = meta_title:gsub("%.rpp$", "")
  end
  return meta_title
end

--- Dialogue Enregistrer sous ; annulation → nil. Fallback : saisie du chemin (GetUserInputs).
local function pick_save_filepath(default_full)
  local dir = ""
  local fname = "conductor-cues.json"
  if default_full and default_full ~= "" then
    local d, f = default_full:match("^(.+[/\\])([^/\\]+)$")
    if f and f ~= "" then
      dir, fname = d, f
    else
      fname = default_full
    end
  end
  if dir ~= "" and not dir:match("[/\\]$") then
    dir = dir .. "/"
  end

  if reaper.APIExists("JS_Dialog_BrowseForSaveFile") then
    local rv, path = reaper.JS_Dialog_BrowseForSaveFile(
      "Exporter conductor-cues.json",
      dir or "",
      fname,
      "JSON (*.json)\0*.json\0Tous les fichiers (*.*)\0*.*\0\0"
    )
    if path and path ~= "" then
      if not path:lower():match("%.json$") then
        path = path .. ".json"
      end
      return path
    end
    return nil
  end

  if reaper.APIExists("GetUserFileNameForSave") then
    local rv, path = reaper.GetUserFileNameForSave("Exporter conductor-cues.json", "json", dir or "")
    if rv and path and path ~= "" then
      if not path:lower():match("%.json$") then
        path = path .. ".json"
      end
      return path
    end
    return nil
  end

  local ok, res = reaper.GetUserInputs(
    "Exporter conductor-cues.json",
    1,
    "Chemin complet du fichier .json:,extrawidth=520",
    default_full
  )
  if ok and res and res ~= "" then
    local path = res:match("^%s*(.-)%s*$")
    if not path:lower():match("%.json$") then
      path = path .. ".json"
    end
    return path
  end
  return nil
end

local function get_ppq_per_quarter(take, item)
  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local qn0 = reaper.TimeMap2_timeToQN(0, pos)
  local t0 = reaper.TimeMap2_QNToTime(0, qn0)
  local t1 = reaper.TimeMap2_QNToTime(0, qn0 + 1.0)
  local ppq0 = reaper.MIDI_GetPPQPosFromProjTime(take, t0)
  local ppq1 = reaper.MIDI_GetPPQPosFromProjTime(take, t1)
  local d = ppq1 - ppq0
  if not d or d <= 0 then return 960.0 end
  return d
end

--- Tick MIDI global aligné sur la timeline projet (QN × ppq), cohérent multi-pistes.
local function proj_time_to_global_tick(proj, proj_t, ppq_per_quarter)
  local qn = reaper.TimeMap2_timeToQN(proj, proj_t)
  return math.floor(qn * ppq_per_quarter + 0.5)
end

--- Nom de note solfège (FR) + numéro d’octave ; note MIDI entière 0–127.
local FRENCH_NOTE_NAMES = {
  "Do", "Do#", "Ré", "Ré#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"
}
local function midi_note_name_fr(note)
  local n = math.floor(note + 0.5)
  n = math.max(0, math.min(127, n))
  local pc = n % 12
  local oct = math.floor(n / 12) - 1
  return FRENCH_NOTE_NAMES[pc + 1] .. tostring(oct)
end

--- Cents affichés comme sur la consigne pupitre : troncature vers zéro (ex. -82.6 → -82).
local function cents_display_trunc(c)
  if c >= 0 then
    return math.floor(c)
  end
  return math.ceil(c)
end

local function hz_display_int(hz)
  return math.floor(hz + 0.5)
end

local function collect_pitch_bends(take, cccnt)
  local out = {}
  for ci = 0, cccnt - 1 do
    local rv, sel, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ci)
    if rv then
      local cm = chanmsg or 0
      if cm >= 224 and cm < 240 then
        local b14 = msg2 + msg3 * 128
        if b14 < 0 then b14 = 0 end
        if b14 > 16383 then b14 = 16383 end
        out[#out + 1] = { ppq = ppqpos, bend14 = b14 }
      end
    end
  end
  table.sort(out, function(a, b) return a.ppq < b.ppq end)
  return out
end

local function last_value_at_or_before(events, ppq, getv, defaultv)
  local last = defaultv
  for i = 1, #events do
    local e = events[i]
    if e.ppq <= ppq + 1e-9 then
      last = getv(e)
    else
      break
    end
  end
  return last
end

--- Retourne c_per_q (cents/noire) et une table dbg { src, bend_count, ... }.
local function transition_cents_per_quarter_around_note(bends, note_ppq, ppq_per_q)
  local dbg = {
    bend_count = bends and #bends or 0,
    transitions_n = 0,
    src = "none",
    detail = "",
    c_per_q = 0.0,
  }
  if not bends or #bends < 2 then
    dbg.detail = "#bends < 2"
    return 0.0, dbg
  end
  local g = CONFIG.gliss
  local eps = g.stable_epsilon_cents or 2.0
  local min_stable_ppq = (g.stable_min_quarters or 0.125) * (ppq_per_q or 960.0)
  local min_delta = g.transition_min_delta_cents or 4.0
  local flat_lookback = (g.flat_lookback_quarters or 2.0) * (ppq_per_q or 960.0)
  local flat_spread_max = g.flat_max_spread_cents or min_delta
  local fb_span = (g.fallback_max_quarters or 4.0) * (ppq_per_q or 960.0)

  local events = {}
  for i = 1, #bends do
    local e = bends[i]
    events[#events + 1] = {
      ppq = e.ppq,
      cents = pitch_bend_14_to_cents(e.bend14, CONFIG.pitch_bend_range_semitones),
    }
  end

  -- Pas de mouvement de bend dans la fenêtre locale → instantané.
  -- Il faut AU MOINS 2 points bend dans la fenêtre : avec 1 seul message, spread=0 à tort
  -- (cas fréquent) et tout le fichier tombait en glissSpeed 0.
  do
    local min_c, max_c = nil, nil
    local nwin = 0
    for i = 1, #events do
      local e = events[i]
      if e.ppq <= note_ppq + 1e-9 and e.ppq >= note_ppq - flat_lookback then
        nwin = nwin + 1
        if not min_c then
          min_c = e.cents
          max_c = e.cents
        else
          min_c = math.min(min_c, e.cents)
          max_c = math.max(max_c, e.cents)
        end
      end
    end
    if nwin >= 2 and min_c and max_c and (max_c - min_c) <= flat_spread_max then
      dbg.src = "flat_window"
      dbg.detail = string.format("spread=%.2f ct sur %.2f noires (%d pts)", max_c - min_c, flat_lookback / (ppq_per_q or 960.0), nwin)
      return 0.0, dbg
    end
  end

  local stable_start = nil
  local stable_ref = nil
  local last_stable = nil
  local transitions = {}

  local function push_transition_if_valid(next_stable)
    if not last_stable or not next_stable then
      return
    end
    local dt = next_stable.start_ppq - last_stable.end_ppq
    local dc = next_stable.ref_cents - last_stable.ref_cents
    if dt > 1e-9 and math.abs(dc) >= min_delta then
      transitions[#transitions + 1] = {
        t0 = last_stable.end_ppq,
        t1 = next_stable.start_ppq,
        c_per_q = math.abs(dc / dt) * ppq_per_q,
      }
    end
  end

  for i = 1, #events do
    local e = events[i]
    if stable_start == nil then
      stable_start = e.ppq
      stable_ref = e.cents
    else
      if math.abs(e.cents - stable_ref) <= eps then
        -- continue plateau
      else
        local stable_end = events[i - 1].ppq
        if (stable_end - stable_start) >= min_stable_ppq then
          local st = {
            start_ppq = stable_start,
            end_ppq = stable_end,
            ref_cents = stable_ref,
          }
          push_transition_if_valid(st)
          last_stable = st
        end
        stable_start = e.ppq
        stable_ref = e.cents
      end
    end
  end

  if stable_start ~= nil then
    local stable_end = events[#events].ppq
    if (stable_end - stable_start) >= min_stable_ppq then
      local st = {
        start_ppq = stable_start,
        end_ppq = stable_end,
        ref_cents = stable_ref,
      }
      push_transition_if_valid(st)
      last_stable = st
    end
  end

  dbg.transitions_n = #transitions

  -- Ne pas réutiliser « la dernière transition passée » : une note sur un plateau après le gliss
  -- n'est pas dans l'intervalle [t0,t1] et doit être traitée comme instantané / fallback local.
  local best = nil
  for i = 1, #transitions do
    local tr = transitions[i]
    if note_ppq >= tr.t0 - 1e-9 and note_ppq <= tr.t1 + 1e-9 then
      best = tr
      break
    end
  end

  if best then
    dbg.src = "stable"
    dbg.c_per_q = best.c_per_q
    return best.c_per_q, dbg
  end

  -- Fallback robuste : si aucun plateau valide n'a été trouvé (cas fréquent si
  -- peu d'événements PB), on calcule la pente sur les 2 derniers bends
  -- significatifs avant (ou au) déclenchement de la note.
  local b2 = nil
  local b1 = nil
  for i = #events, 1, -1 do
    local e = events[i]
    if e.ppq <= note_ppq + 1e-9 and e.ppq >= note_ppq - fb_span then
      if not b2 then
        b2 = e
      elseif math.abs(e.cents - b2.cents) >= min_delta then
        b1 = e
        break
      end
    end
  end
  if b1 and b2 then
    local dt = b2.ppq - b1.ppq
    if dt > 1e-9 then
      local cq = math.abs((b2.cents - b1.cents) / dt) * ppq_per_q
      dbg.src = "fallback"
      dbg.c_per_q = cq
      dbg.fallback_ppq0 = b1.ppq
      dbg.fallback_ppq1 = b2.ppq
      dbg.fallback_dcents = b2.cents - b1.cents
      return cq, dbg
    end
    dbg.detail = "fallback dt=0"
    return 0.0, dbg
  end
  dbg.detail = "no stable transition; no fallback pair (delta<min or single point before note)"
  return 0.0, dbg
end

local function slope_to_gliss_speed(c_per_q)
  local g = CONFIG.gliss
  c_per_q = math.abs(c_per_q or 0.0)
  if c_per_q < g.epsilon_cents_per_quarter then
    return 0
  elseif c_per_q >= g.very_fast_at then
    return 1
  elseif c_per_q >= g.fast_at then
    return 2
  elseif c_per_q >= (g.slow_at or 8) then
    -- Avant : seuil med_at (25) → presque tout bend « réel » tombait en 4 (très lent).
    return 3
  else
    return 4
  end
end

--- Pour debug : pourquoi gs peut rester 0 malgré c_per_q > 0.
local function gliss_speed_debug_reason(gs, c_per_q)
  local g = CONFIG.gliss
  if gs ~= 0 then
    return ""
  end
  if c_per_q < g.epsilon_cents_per_quarter + 1e-12 then
    return string.format("gs=0 car c_per_q=%.6f < epsilon=%.6f", c_per_q, g.epsilon_cents_per_quarter)
  end
  return "gs=0 (inattendu)"
end

local function velocity_to_volet(vel)
  if not vel then return 0.0 end
  vel = math.max(0, math.min(127, math.floor(vel + 0.5)))
  return vel / 127.0
end

--- Numéro de mesure (1-based) et battement dans la mesure (1-based, peut être fractionnaire).
local function measure_beat_from_qn(qn)
  local rv, qms, qme, num, denom = reaper.TimeMap_QNToMeasures(0, qn)
  if not rv then
    return 1, 1.0
  end
  local q = 0.0
  local m = 0
  while q + 1e-9 < qms do
    local rv2, qs, qe, n, d = reaper.TimeMap_QNToMeasures(0, q + 1e-6)
    if not rv2 then
      break
    end
    m = m + 1
    q = qe
  end
  local bar = m + 1
  local span = qme - qms
  if span < 1e-12 then
    return bar, 1.0
  end
  local qn_per_beat = 1.0
  if type(num) == "number" and num > 1e-9 then
    qn_per_beat = span / num
  elseif type(denom) == "number" and denom > 1e-9 then
    -- qn = noires ; 1 battement = 4/denom noires.
    qn_per_beat = 4.0 / denom
  end
  if qn_per_beat < 1e-12 then
    qn_per_beat = 1.0
  end
  local beat = (qn - qms) / qn_per_beat + 1.0
  return bar, beat
end

local function main()
  local reaproj = select(1, reaper.EnumProjects(-1))
  if not reaproj then
    reaproj = 0
  end
  local ppq_ref = nil
  local work = {}

  local tc = reaper.CountTracks(0)
  for ti = 0, tc - 1 do
    local track = reaper.GetTrack(0, ti)
    local ok_name, trname = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    trname = (ok_name and trname) or ("track_" .. tostring(ti))

    local icnt = reaper.CountTrackMediaItems(track)
    for ii = 0, icnt - 1 do
      local item = reaper.GetTrackMediaItem(track, ii)
      local take = reaper.GetActiveTake(item)
      if take and reaper.TakeIsMIDI(take) then
        if not ppq_ref then
          ppq_ref = get_ppq_per_quarter(take, item)
        end
        local rv, notecnt, cccnt, textsyx = reaper.MIDI_CountEvts(take)
        if rv and notecnt > 0 then
          local bends = collect_pitch_bends(take, cccnt)
          for ni = 0, notecnt - 1 do
            local r2, sel, muted, sppq, eppq, chan, pitch, vel = reaper.MIDI_GetNote(take, ni)
            if r2 and vel and vel > 0 then
              local proj_t = reaper.MIDI_GetProjTimeFromPPQPos(take, sppq)
              local proj_t_end = reaper.MIDI_GetProjTimeFromPPQPos(take, eppq)
              local ch1 = midi_channel_to_siren_index(chan)
              work[#work + 1] = {
                reaperTrackIndex = ti,
                trackName = trname,
                midiChannel1 = ch1,
                take = take,
                item = item,
                startppq = sppq,
                endppq = eppq,
                proj_t = proj_t,
                proj_t_end = proj_t_end,
                pitch = pitch,
                vel = vel,
                chan = chan,
                bends = bends,
                ppq_per_q = ppq_ref,
              }
            end
          end
        end
      end
    end
  end

  if #work == 0 then
    reaper.ShowMessageBox(
      "Aucune note MIDI trouvée sur les pistes du projet.\n" ..
        "Placez des items MIDI (toutes pistes analysées).",
      "Mecaviv conductor cues",
      0
    )
    return
  end

  if not ppq_ref or ppq_ref <= 0 then
    ppq_ref = 960.0
  end

  table.sort(work, function(a, b)
    if a.proj_t ~= b.proj_t then
      return a.proj_t < b.proj_t
    end
    if a.midiChannel1 ~= b.midiChannel1 then
      return a.midiChannel1 < b.midiChannel1
    end
    if a.reaperTrackIndex ~= b.reaperTrackIndex then
      return a.reaperTrackIndex < b.reaperTrackIndex
    end
    return a.startppq < b.startppq
  end)

  local outfn = pick_save_filepath(default_json_export_path())
  if not outfn then
    return
  end

  local meta_title = project_title_for_metadata(outfn)

  local parts = {}
  parts[#parts + 1] = '{\n  "version": 1,\n  "metadata": {\n'
  parts[#parts + 1] = string.format('    "title": "%s",\n', esc_json_str(meta_title))
  parts[#parts + 1] = string.format('    "midiFile": "./score.mid",\n')
  parts[#parts + 1] = string.format('    "ppq": %d,\n', math.floor(ppq_ref + 0.5))
  parts[#parts + 1] = '    "tickOrigin": "project_timeline_qn",\n'
  parts[#parts + 1] = '    "exportScope": "all_midi_tracks",\n'
  parts[#parts + 1] = '    "note": "sirenTrackIndex = canal MIDI 1–16 (note) ; sirenTrackName = piste Reaper.",\n'
  parts[#parts + 1] = string.format('    "pitchBendRangeSemitones": %.1f,\n', CONFIG.pitch_bend_range_semitones)
  parts[#parts + 1] = '    "voletSource": "note_velocity",\n'
  parts[#parts + 1] = '    "sirenChannels": [\n'

  local seen_ch = {}
  local ch_list = {}
  for i = 1, #work do
    local w = work[i]
    local ch = w.midiChannel1
    if not seen_ch[ch] then
      seen_ch[ch] = true
      ch_list[#ch_list + 1] = { midiChannel = ch, trackName = w.trackName }
    end
  end
  table.sort(ch_list, function(a, b) return a.midiChannel < b.midiChannel end)
  for i = 1, #ch_list do
    local st = ch_list[i]
    local comma = ","
    if i == #ch_list then comma = "" end
    parts[#parts + 1] = string.format(
      '      { "midiChannel": %d, "trackName": "%s" }%s\n',
      st.midiChannel,
      esc_json_str(st.trackName),
      comma
    )
  end
  parts[#parts + 1] = '    ],\n'
  parts[#parts + 1] = '    "sirenToPupitre": {}\n'
  parts[#parts + 1] = '  },\n  "cues": [\n'

  if GLISS_DEBUG then
    local g = CONFIG.gliss
    reaper.ShowConsoleMsg(string.format(
      "[Mecaviv gliss] DEBUG c/noire: gs0<%.3f | gs1>=%.0f | gs2>=%.0f | gs3>=%.0f | gs4 [%.3f .. %.3f[ | stable_eps=%.1f min_stable_q=%.3f min_dc=%.1f\n"
        .. "  instant si spread<=%.1f ct sur %.1f noires ; fallback limité à %.1f noires\n",
      g.epsilon_cents_per_quarter,
      g.very_fast_at,
      g.fast_at,
      g.slow_at or 8,
      g.epsilon_cents_per_quarter,
      g.slow_at or 8,
      g.stable_epsilon_cents or 2.0,
      g.stable_min_quarters or 0.125,
      g.transition_min_delta_cents or 4.0,
      g.flat_max_spread_cents or 3.0,
      g.flat_lookback_quarters or 4.0,
      g.fallback_max_quarters or 4.0
    ))
  end

  for i = 1, #work do
    local w = work[i]
    local tick = proj_time_to_global_tick(reaproj, w.proj_t, ppq_ref)
    local end_tick = proj_time_to_global_tick(reaproj, w.proj_t_end, ppq_ref)
    local duration_ticks = math.max(0, end_tick - tick)
    local bend14 = last_value_at_or_before(w.bends, w.startppq, function(e) return e.bend14 end, 8192)
    local cents = pitch_bend_14_to_cents(bend14, CONFIG.pitch_bend_range_semitones)
    local hz = midi_to_hz(w.pitch + cents / 100.0)
    local c_per_q, dbg_gliss = transition_cents_per_quarter_around_note(w.bends, w.startppq, w.ppq_per_q)
    local gs = slope_to_gliss_speed(c_per_q)
    local volet = velocity_to_volet(w.vel)

    -- Bend à la fin de la note = cible du glissando
    local end_bend14 = last_value_at_or_before(w.bends, w.endppq, function(e) return e.bend14 end, bend14)
    local end_cents = pitch_bend_14_to_cents(end_bend14, CONFIG.pitch_bend_range_semitones)
    local end_hz = midi_to_hz(w.pitch + end_cents / 100.0)

    -- Repli intra-note : si gs=0 mais le bend change pendant la note, calculer la
    -- vitesse depuis le mouvement réel (cas fréquent : ghost note stable avant → gliss pendant la note ouverte).
    local gliss_delta_pre = math.abs(end_cents - cents)
    if gs == 0 and gliss_delta_pre > 3.0 then
      local note_dur_q = (w.endppq - w.startppq) / (w.ppq_per_q or 960.0)
      if note_dur_q > 1e-9 then
        local in_note_cperq = gliss_delta_pre / note_dur_q
        gs = slope_to_gliss_speed(in_note_cperq)
        c_per_q = in_note_cperq
        dbg_gliss.src = "intra_note"
        dbg_gliss.detail = string.format("delta=%.1fct sur %.2fq -> %.3f ct/q", gliss_delta_pre, note_dur_q, in_note_cperq)
      end
    end

    if GLISS_DEBUG and (not GLISS_DEBUG_MAX_CUES or i <= GLISS_DEBUG_MAX_CUES) then
      local extra = gliss_speed_debug_reason(gs, c_per_q)
      local fb = ""
      if dbg_gliss.src == "fallback" and dbg_gliss.fallback_ppq0 then
        fb = string.format(" fb[ppq %.1f→%.1f dc=%.1fct]", dbg_gliss.fallback_ppq0, dbg_gliss.fallback_ppq1, dbg_gliss.fallback_dcents or 0)
      end
      reaper.ShowConsoleMsg(string.format(
        "[Mecaviv gliss] cue=%d ch=%d note_ppq=%.2f bend_cc=%d tr=%d src=%s c_per_q=%.4f gs=%d | %s%s%s\n",
        i,
        w.midiChannel1,
        w.startppq,
        dbg_gliss.bend_count or 0,
        dbg_gliss.transitions_n or 0,
        dbg_gliss.src or "?",
        c_per_q,
        gs,
        dbg_gliss.detail ~= "" and dbg_gliss.detail or "ok",
        fb,
        extra ~= "" and (" | " .. extra) or ""
      ))
    end

    local ndisp = cents_display_trunc(cents)
    local ct_str
    if ndisp > 0 then
      ct_str = string.format("+%dct", ndisp)
    elseif ndisp < 0 then
      ct_str = string.format("%dct", ndisp)
    else
      ct_str = "0ct"
    end
    -- Note de départ du gliss (anchor + bend au note-on)
    local midi_start = w.pitch + cents / 100.0
    local note_fr_start = midi_note_name_fr(midi_start)
    local n_start = math.floor(midi_start + 0.5)
    -- Note d'arrivée du gliss (anchor + bend à la fin de la note)
    local midi_end = w.pitch + end_cents / 100.0
    local note_fr_end = midi_note_name_fr(midi_end)
    local n_end = math.floor(midi_end + 0.5)
    local end_ndisp = cents_display_trunc(end_cents)
    local end_ct_str
    if end_ndisp > 0 then
      end_ct_str = string.format("+%dct", end_ndisp)
    elseif end_ndisp < 0 then
      end_ct_str = string.format("%dct", end_ndisp)
    else
      end_ct_str = "0ct"
    end
    -- Seuil : gliss significatif si écart > 3 cents
    local gliss_delta = math.abs(end_cents - cents)
    local text
    if gs > 0 and gliss_delta > 3.0 then
      text = string.format(
        "%s %s (n%d) %s \xe2\x86\x92 %s (n%d) %s  vel.%d  %dhz\xe2\x86\x92%dhz  gliss:%d  volet: %.1f",
        w.trackName,
        note_fr_start, n_start, ct_str,
        note_fr_end, n_end, end_ct_str,
        w.vel,
        hz_display_int(hz), hz_display_int(end_hz),
        gs,
        volet
      )
    else
      text = string.format(
        "%s %s (n%d) %s  vel.%d  ->  %dhz  gliss:%d  volet: %.1f",
        w.trackName,
        note_fr_start, n_start, ct_str,
        w.vel,
        hz_display_int(hz),
        gs,
        volet
      )
    end

    local t_ms = math.floor(w.proj_t * 1000.0 + 0.5)
    local bar, beat_in_bar = measure_beat_from_qn(reaper.TimeMap2_timeToQN(0, w.proj_t))

    local comma = ","
    if i == #work then comma = "" end
    parts[#parts + 1] = string.format('    {\n      "id": "c%d",\n      "tick": %d,\n', i, tick)
    parts[#parts + 1] = string.format('      "endTick": %d,\n      "durationTicks": %d,\n', end_tick, duration_ticks)
    parts[#parts + 1] = string.format(
      '      "bar": %d,\n      "beatInBar": %.4f,\n      "tMs": %d,\n',
      bar,
      beat_in_bar,
      t_ms
    )
    parts[#parts + 1] = string.format(
      '      "sirenTrackIndex": %d,\n      "sirenTrackName": "%s",\n',
      w.midiChannel1,
      esc_json_str(w.trackName)
    )
    parts[#parts + 1] = '      "targets": [],\n'
    parts[#parts + 1] = string.format('      "text": "%s",\n', esc_json_str(text))
    parts[#parts + 1] = string.format('      "midiAnchor": %.4f,\n', w.pitch * 1.0)
    parts[#parts + 1] = string.format('      "targetCents": %.4f,\n', cents)
    parts[#parts + 1] = string.format('      "targetFrequencyHz": %.6f,\n', hz)
    parts[#parts + 1] = string.format('      "glissSpeed": %d,\n', gs)
    parts[#parts + 1] = string.format('      "glissTargetCents": %.4f,\n', end_cents)
    parts[#parts + 1] = string.format('      "glissTargetFrequencyHz": %.6f,\n', end_hz)
    parts[#parts + 1] = string.format('      "voletOpen": %.6f\n    }%s\n', volet, comma)
  end

  parts[#parts + 1] = "  ]\n}\n"
  local body = table.concat(parts)

  local fh = io.open(outfn, "w")
  if not fh then
    reaper.ShowMessageBox("Impossible d’écrire :\n" .. tostring(outfn), "Erreur", 0)
    return
  end
  fh:write(body)
  fh:close()
  reaper.ShowMessageBox(
    string.format("Fichier écrit :\n%s\n\n%d consigne(s), %d canal(aux) MIDI distinct(s).", outfn, #work, #ch_list),
    "Mecaviv conductor cues",
    0
  )
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Mecaviv export conductor cues (toutes pistes)", -1)

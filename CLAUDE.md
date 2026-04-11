# SugarWave

Retrowave-styled Garmin watchface showing live CGM data. Target: Forerunner 970. Language: Monkey C (Connect IQ).

## Architecture

```
SugarWaveApp.mc        — App lifecycle, background scheduling, Storage bridge
SugarWaveBgService.mc  — Background temporal event: fetches from Strimma/xDrip local server
SugarWaveView.mc       — Main watchface rendering (high-power + low-power modes)
SugarWaveDelegate.mc   — Input handler (tap toggles detail graph mode)
Conversions.mc         — Unit conversion, color constants, staleness, direction enum
GraphRenderer.mc       — BG graph drawing (scrolling timeline, zone shading)
ArrowRenderer.mc       — Trend arrow polygon rendering
NeonRenderer.mc        — Glow/scanline effects for the retrowave aesthetic
Secrets.mc             — API credentials (gitignored, not currently used)
```

## Data Flow

1. `SugarWaveApp` schedules a background temporal event every ~5 min
2. `SugarWaveBgService.onTemporalEvent()` fetches CGM data based on `dataSource` setting:
   - **Local (0):** `http://127.0.0.1:17580/sgv.json` via GCM proxy (known to be flaky)
   - **Nightscout (1):** `https://<url>/api/v1/entries.json` with `api-secret` header and time-based filtering (`find[date][$gt]`)
3. Request uses time-based filtering (graphDuration minutes) and caps count at `BG_EXIT_MAX` (90) to avoid OOM in background service. Response is thinned on-device if it still exceeds limit.
4. `SugarWaveApp.onBackgroundData()` stores readings in `Application.Storage` (or error code in `cgmError`)
5. `SugarWaveView.onUpdate()` reads from Storage, renders watchface (shows `E:<code>` on error)

## Key Constants

- `BG_EXIT_MAX = 90` — max entries through `Background.exit()` (empirically determined)
- `STALE_MINUTES = 11` — stale threshold (red, strikethrough)
- Fresh <6 min (cyan), warning 6–10 min (orange), stale >=11 min (red)
- Graph Y range: 2.0–20.0 mmol/L
- Detail mode timeout: 8 seconds

## Settings

Properties in `resources/settings/properties.xml`:
- `dataSource` — 0=local (Strimma/xDrip+), 1=Nightscout (remote HTTPS)
- `nightscoutUrl` — Nightscout hostname (without https://)
- `nightscoutToken` — API secret sent as `api-secret` header (not NS token — naming is legacy)
- `bgLow` / `bgHigh` — BG zone thresholds (stored as mmol/L * 10)
- `graphDuration` — graph time window in minutes (30–180). Used for time-based API filtering, count capped at BG_EXIT_MAX (90).
- `comp1`–`comp4` — complication slots (0=steps, 1=floors, 2=HR, 3=temp, 4=stress, 5=recovery, 6=cal, 7=battery body, 8=battery watch, 9=notifications)
- `comp4Press` — complication shown on tap (adds 10=calendar)
- `lowPowerMode` — always-on display toggle

## Build

```bash
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc/bin"
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key.der"
"$SDK/monkeyc" -e -o build/SugarWave.iq -f monkey.jungle -y "$KEY" -d fr970 -w
```

Always build `.iq` (not `.prg`). See parent `garmin/CLAUDE.md` for crash-at-launch gotchas.

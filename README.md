# SugarWave

Retrowave-styled Garmin watchface with live CGM blood glucose data. Displays BG value, trend arrow, delta, reading age, a scrolling graph, and configurable complications — all with a neon-on-black AMOLED aesthetic.

**Target device:** Forerunner 970

------------------------
## PLEASE READ THIS ADVISORY FIRST

Never make a medical decision based on a reading that you see on this app. Always perform a fingerstick blood glucose check first.

------------------------
## Data Source

SugarWave supports two data sources, configured in the watchface settings:

### Option 1: Strimma / xDrip+ (local, default)

Fetches CGM data from a local web server on your phone via the Garmin Connect Mobile proxy. Compatible sources:

1. **Strimma** (Android) — recommended
2. **xDrip+** (Android)
3. **Diabox** (Android) — uses the same xDrip-compatible local server

All three serve data on `http://127.0.0.1:17580/sgv.json`. No internet connection required.

**Setup — Strimma:** Enable the local web server (Settings > Data > Local Web Server)

**Setup — xDrip+:** Enable the web server (Settings > Inter-App Settings > enable "xDrip Web Server", but *not* "Open Web Server")

**Setup — Diabox:** Enable "Share data with smartwatches" (Settings > Integrations)

**Test:** Query `http://127.0.0.1:17580/sgv.json?count=2` in your phone's browser. If you see JSON with timestamps and glucose values, the data source is configured correctly.

**Known issue:** The local server mode relies on Garmin Connect Mobile's localhost proxy, which is known to be flaky. Requests may intermittently time out (-300 errors) even when the local server is running correctly. This appears to be a Garmin Connect Mobile issue, not a problem with Strimma or xDrip+. If you experience persistent timeouts, try restarting Garmin Connect Mobile or switching to Nightscout mode.

### Option 2: Nightscout (remote)

Fetches CGM data from a Nightscout-compatible server over HTTPS. Requires an internet connection.

**Setup:**
1. In the watchface settings, set Data Source to **Nightscout (remote)**
2. Enter your Nightscout URL (without `https://`), e.g. `my-ns-site.herokuapp.com`
3. If your Nightscout requires authentication, enter the API secret (the `API_SECRET` value from your Nightscout configuration)

The secret is sent as an `api-secret` header, matching how xDrip+, Loop, Spike, and other Nightscout clients authenticate.

**Test:** Visit `https://<YOUR-URL>/api/v1/entries/sgv.json?count=2` in a browser. If you see JSON with glucose values, it's configured correctly.

------------------------
## Watchface Settings

Configure via the Garmin Connect Mobile app or Garmin Express:

| Setting | Options | Default |
|---------|---------|---------|
| Data Source | Strimma/xDrip+ (local) / Nightscout (remote) | Local |
| Nightscout URL | your-site.example.com | (empty) |
| API Secret | Nightscout API secret | (empty) |
| Low Threshold | 3.0 – 5.0 mmol/L | 4.0 |
| High Threshold | 7.0 – 12.0 mmol/L | 10.0 |
| Graph Duration | 30 / 60 / 90 / 120 / 150 / 180 min | 60 |
| Complications 1–4 | Steps, Floors, HR, Temp, Stress, Recovery, Calories, Body Battery, Watch Battery, Notifications | Varies |
| Comp 4 Press Target | Same as above + Calendar | Calendar |
| Always-On Display | Enabled / Disabled | Enabled |

------------------------
## How It Works

- The Garmin SDK allows background data fetching every **5 minutes**. Each fetch retrieves readings matching the configured graph duration.
- On-device **thinning** automatically downsamples readings if needed to fit Garmin's background data transfer limit (max ~90 entries). At 180 min with 1-min readings, you get ~2-min resolution on the graph.
- **Staleness indicators**: reading age is color-coded — fresh (<6 min), warning (6–10 min), stale (>=11 min). Stale readings get a strikethrough on the BG value.
- The graph scrolls with wall-clock time, so stale data visibly drifts left.

------------------------
## Troubleshooting

| Error | Meaning | Solution |
|-------|---------|----------|
| `Bluetooth!` | Phone not connected | Reconnect phone to watch |
| `Error: -1` | Generic BLE error | Check Bluetooth settings |
| `Error: -2` | BLE timeout | Check Bluetooth settings |
| `Error: -104` | No BLE connection | Check Bluetooth settings |
| `Error: -300` | Request timed out | Local mode: GCM proxy may be flaky — restart GCM or try Nightscout mode. Remote mode: check internet connection. |
| `Error: -400` | Invalid response body | Check data source configuration |
| `Error: -401` | Unauthorized | Nightscout mode: check URL and token |
| `Error: -403` | Out of memory | Report as bug |
| `Error: -404` | Page not found | Local mode: verify web server is running. Nightscout mode: check URL. |

*Q: The glucose data doesn't appear immediately.*
A: The Garmin SDK only allows data polling every 5 minutes. Wait at least 5 minutes after setup.

*Q: The graph looks coarse at long durations.*
A: At 150–180 min, on-device thinning reduces resolution to ~2 min between points. This is expected.

------------------------
## Building

```bash
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc/bin"
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key.der"
"$SDK/monkeyc" -e -o build/SugarWave.iq -f monkey.jungle -y "$KEY" -d fr970 -w
```

Always build `.iq` files (not `.prg`). PRG skips strict type checking and code that works in the simulator may crash on device.

------------------------
## License

MIT

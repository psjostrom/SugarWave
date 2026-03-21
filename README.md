# SugarWave

Retrowave-styled Garmin watchface with live CGM blood glucose data. Displays BG value, trend arrow, delta, reading age, a scrolling graph, and configurable complications — all with a neon-on-black AMOLED aesthetic.

**Target device:** Forerunner 970

------------------------
## PLEASE READ THIS ADVISORY FIRST

Never make a medical decision based on a reading that you see on this app. Always perform a fingerstick blood glucose check first.

------------------------
## Data Source

SugarWave fetches CGM data from a local web server on your phone via the Garmin Connect Mobile proxy. Compatible sources:

1. **Strimma** (Android) — recommended
2. **xDrip+** (Android)
3. **Diabox** (Android) — uses the same xDrip-compatible local server

All three serve data on `http://127.0.0.1:17580/sgv.json`. No internet connection required.

### Setup — Strimma
1. In Strimma, enable the local web server (Settings > Data > Local Web Server)
2. Install the watchface on your Garmin device

### Setup — xDrip+
1. In xDrip+, enable the web server (Settings > Inter-App Settings > enable "xDrip Web Server", but *not* "Open Web Server")
2. Install the watchface on your Garmin device

### Setup — Diabox
1. In Diabox, enable "Share data with smartwatches" (Settings > Integrations)
2. Install the watchface on your Garmin device

### Test your setup
Query `http://127.0.0.1:17580/sgv.json?count=2` in your phone's browser. If you see JSON with timestamps and glucose values, the data source is configured correctly.

------------------------
## Watchface Settings

Configure via the Garmin Connect Mobile app or Garmin Express:

| Setting | Options | Default |
|---------|---------|---------|
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
| `Error: -300` | Request timed out | Verify Strimma/xDrip+ web server is enabled |
| `Error: -400` | Invalid response body | Check Strimma/xDrip+ configuration |
| `Error: -403` | Out of memory | Report as bug |
| `Error: -404` | Page not found | Verify Strimma/xDrip+ web server is running |

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

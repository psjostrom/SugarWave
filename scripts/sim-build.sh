#!/bin/bash
# Build SugarWave for simulator with mock CGM data injected.
# Mock data is created temporarily and removed after the build.
set -euo pipefail

SDK="$(ls -dt "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/"*/bin | head -1)"  # newest installed SDK
KEY="$HOME/Library/Application Support/Garmin/ConnectIQ/developer_key.der"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIM_SRC="$ROOT/source-sim"
MOCK_FILE="$SIM_SRC/MockData.mc"
VIEW_FILE="$ROOT/source/SugarWaveView.mc"
JUNGLE="$ROOT/monkey-sim.jungle"

cleanup() {
    rm -f "$MOCK_FILE"
    rmdir "$SIM_SRC" 2>/dev/null || true
    # Revert view file — remove the MockData.seed() call
    sed -i '' '/MockData\.seed/d' "$VIEW_FILE"
    # Restore jungle — remove source-sim path
    sed -i '' 's|^fr970\.sourcePath = source;source-sim$||' "$JUNGLE"
}
trap cleanup EXIT

# Create source-sim/ with mock data module
mkdir -p "$SIM_SRC"
cat > "$MOCK_FILE" << 'MC'
import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

module MockData {
    function seed() as Void {
        // Always re-seed so timestamps stay fresh
        var nowMs = Time.now().value().toLong() * 1000l;

        // 72 readings (~6h) — realistic curve: stable → rise → high → falling back
        var readings = [] as Array;
        for (var i = 0; i < 72; i++) {
            // Work backwards: i=0 is newest
            var t = i;
            var sgv = 120;
            if (t < 8) { sgv = 252 + t * 36; }             // falling fast: newest=252(14.0) was higher
            else if (t < 20) { sgv = 227 - (t - 8) * 6; }  // was falling from peak
            else if (t < 35) { sgv = 155 + (t - 20) * 3; }  // gentle rise
            else if (t < 50) { sgv = 200 - (t - 35) * 4; }  // descent
            else if (t < 62) { sgv = 140 + (t - 50) * 5; }  // earlier rise
            else { sgv = 140 - (t - 62) * 2; }              // stable start

            if (sgv < 72) { sgv = 72; }
            if (sgv > 270) { sgv = 270; }

            var entry = {
                "date" => nowMs - (i.toLong() * 300000l),
                "sgv" => sgv
            } as Dictionary;
            readings.add(entry);
        }
        Application.Storage.setValue("cgmReadings", readings);
    }
}
MC

# Inject seed call into SugarWaveView.initialize()
sed -i '' 's|WatchFace.initialize();|WatchFace.initialize();\
        if ($ has :MockData) { MockData.seed(); }|' "$VIEW_FILE"

# Add source-sim to jungle
echo 'fr970.sourcePath = source;source-sim' >> "$JUNGLE"

# Build
"$SDK/monkeyc" -o "$ROOT/build/SugarWave.prg" -f "$JUNGLE" -y "$KEY" -d fr970 -w

echo "Built: $ROOT/build/SugarWave.prg"
echo "Run:   \"$SDK/monkeydo\" \"$ROOT/build/SugarWave.prg\" fr970"

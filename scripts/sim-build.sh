#!/bin/bash
# Build SugarWave for simulator with mock CGM data injected.
# Mock data is created temporarily and removed after the build.
set -euo pipefail

SDK="/Users/persjo/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-8.4.0-2025-12-03-5122605dc"
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
        var existing = Application.Storage.getValue("cgmReadings");
        if (existing != null) { return; }

        var sgvs = [252, 270, 280, 275, 260, 245, 230, 220, 210, 200,
                    195, 190, 185, 180, 175, 170, 165, 160, 155, 150,
                    145, 140, 138, 135];
        var nowMs = Time.now().value().toLong() * 1000l - 600000l;
        var readings = [] as Array;
        for (var i = 0; i < sgvs.size(); i++) {
            var entry = {
                "date" => nowMs - (i.toLong() * 300000l),
                "sgv" => sgvs[i]
            } as Dictionary;
            if (i == 0) {
                entry["delta"] = -36;
                entry["direction"] = "DoubleDown";
            }
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
"$SDK/bin/monkeyc" -o "$ROOT/build/SugarWave.prg" -f "$JUNGLE" -y "$KEY" -d fr970 -w

echo "Built: $ROOT/build/SugarWave.prg"
echo "Run:   \"$SDK/bin/monkeydo\" \"$ROOT/build/SugarWave.prg\" fr970"

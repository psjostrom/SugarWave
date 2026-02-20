import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

// Simulator-only mock CGM data. Excluded from device builds via monkey.jungle.
module MockData {
    function seed() as Void {
        // Always re-seed so timestamp stays relative to now
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

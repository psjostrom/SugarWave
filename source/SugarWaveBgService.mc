import Toybox.Application;
import Toybox.System;
import Toybox.Communications;
import Toybox.Background;
import Toybox.Lang;

(:background)
class SugarWaveBgService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() {
        // Match count to graph duration setting (minutes ≈ readings at 1/min)
        var dur = Application.Properties.getValue("graphDuration");
        var count = (dur != null && dur instanceof Number) ? dur as Number : 60;
        Communications.makeWebRequest(
            Secrets.SPRINGA_URL + "/api/sgv?count=" + count,
            null,
            {
                :headers => { "api-secret" => Secrets.SPRINGA_SECRET },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onReceive)
        );
    }

    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode == 200 && data != null) {
            var readings = data as Array;
            var result = [] as Array;
            for (var i = 0; i < readings.size(); i++) {
                var r = readings[i] as Dictionary;
                if (r["date"] == null || r["sgv"] == null) { continue; }
                var dateVal = r["date"];
                var dateLong = (dateVal instanceof Long) ? dateVal as Long :
                    (dateVal instanceof Number) ? (dateVal as Number).toLong() :
                    (dateVal instanceof Double) ? (dateVal as Double).toLong() : 0l;
                var entry = {
                    "date" => dateLong,
                    "sgv" => r["sgv"]
                } as Dictionary;
                if (i == 0) {
                    if (r["delta"] != null) { entry["delta"] = r["delta"]; }
                    if (r["direction"] != null) { entry["direction"] = r["direction"]; }
                }
                result.add(entry);
            }
            Background.exit(result);
        } else {
            Background.exit(responseCode);
        }
    }
}

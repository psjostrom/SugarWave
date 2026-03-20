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
        var dur = Application.Properties.getValue("graphDuration");
        if (dur == null || !(dur instanceof Number)) { dur = 60; }
        var interval = Application.Properties.getValue("cgmInterval");
        if (interval == null || !(interval instanceof Number) || (interval as Number) < 1) { interval = 1; }
        var count = (dur as Number) / (interval as Number);
        if (count > 90) { count = 90; }
        if (count < 6) { count = 6; }
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

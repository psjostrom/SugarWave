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

    // Max entries through Background.exit() — empirically 90 works, 120 fails
    const BG_EXIT_MAX = 90;

    function onTemporalEvent() {
        var dur = Application.Properties.getValue("graphDuration");
        if (dur == null || !(dur instanceof Number)) { dur = 60; }
        var count = dur as Number;
        if (count < 6) { count = 6; }

        var source = Application.Properties.getValue("dataSource");
        if (source == null || !(source instanceof Number)) { source = 0; }

        var url = "";
        var headers = {} as Dictionary;

        if ((source as Number) == 1) {
            // Nightscout (remote HTTPS)
            var nsUrl = Application.Properties.getValue("nightscoutUrl");
            if (nsUrl == null || !(nsUrl instanceof String) || (nsUrl as String).length() == 0) {
                Background.exit(-1);
                return;
            }
            url = "https://" + nsUrl + "/api/v1/entries/sgv.json?count=" + count;
            var secret = Application.Properties.getValue("nightscoutToken");
            if (secret != null && secret instanceof String && (secret as String).length() > 0) {
                headers = { "api-secret" => secret };
            } else {
                headers = { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED };
            }
        } else {
            // Strimma / xDrip+ (local)
            url = "http://127.0.0.1:17580/sgv.json?brief_mode=Y&count=" + count;
            headers = { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED };
        }

        Communications.makeWebRequest(
            url,
            {},
            {
                :headers => headers,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onReceive)
        );
    }

    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode == 200 && data != null) {
            var readings = data as Array;
            // Compute thin factor: keep every Nth entry to fit Background.exit() limit
            var thin = 1;
            if (readings.size() > BG_EXIT_MAX) {
                thin = (readings.size() + BG_EXIT_MAX - 1) / BG_EXIT_MAX;
            }
            var result = [] as Array;
            for (var i = 0; i < readings.size(); i++) {
                // Always keep first entry (latest); thin the rest
                if (i > 0 && thin > 1 && (i % thin) != 0) { continue; }
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

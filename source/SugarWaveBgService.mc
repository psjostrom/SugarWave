import Toybox.Application;
import Toybox.System;
import Toybox.Communications;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Time;

(:background)
class SugarWaveBgService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    // Max entries through Background.exit() — empirically 90 works, 120 fails
    const BG_EXIT_MAX = 90;

    // Safe upper bound for background service JSON parsing
    const COUNT_MAX = 60;

    hidden function normalizeUrl(raw as String) as String {
        if (raw.find("https://") == 0 || raw.find("http://") == 0) {
            if (raw.length() > 8 && raw.substring(raw.length() - 1, raw.length()).equals("/")) {
                return raw.substring(0, raw.length() - 1);
            }
            return raw;
        }
        return "https://" + raw;
    }

    function onTemporalEvent() {
        var dur = Application.Properties.getValue("graphDuration");
        if (dur == null || !(dur instanceof Number)) { dur = 60; }
        var durationMin = dur as Number;
        if (durationMin < 6) { durationMin = 6; }

        // Time-based filtering: fetch entries from the last N minutes
        var sinceMs = Time.now().value().toLong() * 1000l - durationMin.toLong() * 60000l;

        var source = Application.Properties.getValue("dataSource");
        if (source == null || !(source instanceof Number)) { source = 0; }

        var url = "";
        var params = {} as Dictionary;
        var headers = {} as Dictionary;

        if ((source as Number) == 1) {
            // Nightscout (remote HTTPS)
            var nsUrl = Application.Properties.getValue("nightscoutUrl");
            if (nsUrl == null || !(nsUrl instanceof String) || (nsUrl as String).length() == 0) {
                Background.exit(-1);
                return;
            }
            url = normalizeUrl(nsUrl as String) + "/api/v1/entries.json";
            // CIQ appends params dict as query string for GET requests
            params = {
                "count" => COUNT_MAX,
                "find[date][$gt]" => sinceMs.toString()
            };
            var secret = Application.Properties.getValue("nightscoutSecret");
            if (secret != null && secret instanceof String && (secret as String).length() > 0) {
                headers = { "api-secret" => secret };
            } else {
                headers = { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED };
            }
        } else {
            // Strimma / xDrip+ (local)
            url = "http://127.0.0.1:17580/sgv.json?brief_mode=Y&count=" + COUNT_MAX;
            headers = { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED };
        }

        Communications.makeWebRequest(
            url,
            params,
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

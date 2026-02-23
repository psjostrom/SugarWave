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
        Communications.makeWebRequest(
            "http://127.0.0.1:17580/sgv.json?brief_mode=Y&count=36",
            {},
            {
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED,
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onReceive)
        );
    }

    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode == 200 && data != null &&
            data instanceof Lang.Array && (data as Array).size() > 0) {
            var readings = data as Array;
            // Normalize in-place to minimize memory
            for (var i = 0; i < readings.size(); i++) {
                var r = readings[i];
                if (!(r instanceof Dictionary)) { continue; }
                var d = r as Dictionary;
                if (d["date"] == null || d["sgv"] == null) { continue; }
                var dateVal = d["date"];
                var dateLong = (dateVal instanceof Long) ? dateVal as Long :
                    (dateVal instanceof Number) ? (dateVal as Number).toLong() :
                    (dateVal instanceof Double) ? (dateVal as Double).toLong() : 0l;
                if (i == 0) {
                    readings[i] = {
                        "date" => dateLong,
                        "sgv" => d["sgv"],
                        "delta" => d["delta"],
                        "direction" => d["direction"]
                    };
                } else {
                    readings[i] = {
                        "date" => dateLong,
                        "sgv" => d["sgv"]
                    };
                }
            }
            Background.exit(readings);
        } else {
            Background.exit(responseCode);
        }
    }
}

import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:background)
class SugarWaveApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
        Background.deleteTemporalEvent();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        scheduleNextPoll(0l);
        var view = new SugarWaveView();
        return [view, new SugarWaveDelegate(view)];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new SugarWaveBgService()];
    }

    function onBackgroundData(data) as Void {
        var latestDateMs = 0l;

        // Debug: store raw background result info
        if (data instanceof Dictionary) {
            var dict = data as Dictionary;
            var ok = dict.hasKey("ok") ? dict["ok"] : false;
            var rc = dict.hasKey("rc") ? dict["rc"] : -1;
            var n = dict.hasKey("n") ? dict["n"] : 0;

            if (ok == true && dict.hasKey("data")) {
                var readings = dict["data"] as Array;
                if (readings.size() > 0) {
                    Application.Storage.setValue("cgmReadings", readings);
                    var first = readings[0] as Dictionary;
                    if (first.hasKey("date")) {
                        var d = first["date"];
                        if (d instanceof Long) { latestDateMs = d as Long; }
                        else if (d instanceof Number) { latestDateMs = (d as Number).toLong(); }
                    }
                }
                Application.Storage.setValue("bgDebug", "OK rc=" + rc + " n=" + n);
            } else {
                var typeStr = dict.hasKey("type") ? dict["type"].toString() : "?";
                Application.Storage.setValue("bgDebug", "FAIL rc=" + rc + " " + typeStr);
            }
        } else if (data instanceof Lang.Array) {
            // Shouldn't happen with debug envelope, but fallback
            Application.Storage.setValue("bgDebug", "RAW arr=" + (data as Array).size());
        } else {
            Application.Storage.setValue("bgDebug", "UNK " + data.toString().substring(0, 20));
        }
        Application.Storage.setValue("bgDebugTime", Time.now().value());

        scheduleNextPoll(latestDateMs);
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    // Schedule next poll based on data age.
    // Goal: land ~15s after the next expected CGM reading.
    hidden function scheduleNextPoll(latestReadingMs as Long) as Void {
        if (!(Toybox.System has :ServiceDelegate)) { return; }
        var now = Time.now();
        var nowSec = now.value().toLong();
        var wait = 300; // default 5 min

        if (latestReadingMs > 0) {
            // Target: 15s after next expected reading (readings come every 5 min)
            var readingAgeSec = nowSec - latestReadingMs / 1000;
            wait = 300 - readingAgeSec + 15;
            while (wait < 300) { wait += 300; }
        }

        var lastTime = Background.getLastTemporalEventTime();
        var base = (lastTime != null) ? lastTime : now;
        var target = base.add(new Time.Duration(wait.toNumber()));
        // If target is in the past, schedule 5 min from now
        if (target.value() < nowSec) {
            target = now.add(new Time.Duration(300));
        }
        try {
            Background.registerForTemporalEvent(target);
        } catch (ex) {
            // Already registered or too soon — ignore
        }
    }
}

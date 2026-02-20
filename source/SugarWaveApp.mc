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
        return [new SugarWaveView(), new SugarWaveDelegate()];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new SugarWaveBgService()];
    }

    function onBackgroundData(data) as Void {
        var latestDateMs = 0l;
        if (data instanceof Lang.Array && data.size() > 0) {
            var arr = data as Array;
            if (arr[0] instanceof Dictionary && (arr[0] as Dictionary).hasKey("date")) {
                Application.Storage.setValue("cgmReadings", data);
                var d = (arr[0] as Dictionary)["date"];
                if (d instanceof Long) { latestDateMs = d as Long; }
                else if (d instanceof Number) { latestDateMs = (d as Number).toLong(); }
            }
        }
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

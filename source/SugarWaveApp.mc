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
        registerBgService();
        return [new SugarWaveView(), new SugarWaveDelegate()];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new SugarWaveBgService()];
    }

    function onBackgroundData(data) as Void {
        if (data instanceof Lang.Array && data.size() > 0) {
            var arr = data as Array;
            if (arr[0] instanceof Dictionary && (arr[0] as Dictionary).hasKey("date")) {
                Application.Storage.setValue("cgmReadings", data);
            }
        }
        // Re-register for next poll
        registerBgService();
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    hidden function registerBgService() as Void {
        if (!(Toybox.System has :ServiceDelegate)) { return; }
        var lastTime = Background.getLastTemporalEventTime();
        if (lastTime != null) {
            var nextTime = lastTime.add(new Time.Duration(300));
            Background.registerForTemporalEvent(nextTime);
        } else {
            Background.registerForTemporalEvent(Time.now());
        }
    }
}

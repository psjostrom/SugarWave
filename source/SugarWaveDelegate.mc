import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;

class SugarWaveDelegate extends WatchUi.WatchFaceDelegate {

    hidden var mView as SugarWaveView;

    function initialize(view as SugarWaveView) {
        WatchFaceDelegate.initialize();
        mView = view;
    }

    function onPress(clickEvent) as Lang.Boolean {
        // If detail mode is active, any tap dismisses it
        if (mView.isDetailMode()) {
            mView.clearDetailMode();
            WatchUi.requestUpdate();
            return true;
        }

        var coords = clickEvent.getCoordinates();
        var y = coords[1];
        var screenH = System.getDeviceSettings().screenHeight;
        var x = coords[0];
        var screenW = System.getDeviceSettings().screenWidth;

        // Graph zone tap (48%–76% from top) → detail mode
        if (y >= screenH * 0.48 && y <= screenH * 0.76) {
            mView.setDetailMode();
            WatchUi.requestUpdate();
            return true;
        }

        // Complications zone (33%–47% from top)
        if (y < screenH * 0.33 || y > screenH * 0.47) { return false; }

        if (!(Toybox has :Complications)) { return false; }
        var Complications = Toybox.Complications;
        if (!(Complications has :exitTo) || !(Complications has :Id)) { return false; }

        var slot = (x * 4 / screenW).toNumber();
        if (slot >= 4) { slot = 3; }

        // comp4 (slot 3) uses separate press target setting
        var settingKey = (slot == 3) ? "comp4Press" : "comp" + (slot + 1).toString();
        var compSetting = Application.Properties.getValue(settingKey);
        if (compSetting == null) { return false; }

        var compType = getComplicationType(compSetting as Number);
        if (compType == null) { return false; }

        Complications.exitTo(new Complications.Id(compType));
        return true;
    }

    hidden function getComplicationType(setting as Number) as Toybox.Complications.Type? {
        var Complications = Toybox.Complications;
        if (setting == 0 && Complications has :COMPLICATION_TYPE_STEPS) {
            return Complications.COMPLICATION_TYPE_STEPS;
        } else if (setting == 1 && Complications has :COMPLICATION_TYPE_FLOORS_CLIMBED) {
            return Complications.COMPLICATION_TYPE_FLOORS_CLIMBED;
        } else if (setting == 2 && Complications has :COMPLICATION_TYPE_HEART_RATE) {
            return Complications.COMPLICATION_TYPE_HEART_RATE;
        } else if (setting == 3 && Complications has :COMPLICATION_TYPE_CURRENT_TEMPERATURE) {
            return Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE;
        } else if (setting == 4 && Complications has :COMPLICATION_TYPE_STRESS) {
            return Complications.COMPLICATION_TYPE_STRESS;
        } else if (setting == 5 && Complications has :COMPLICATION_TYPE_RECOVERY_TIME) {
            return Complications.COMPLICATION_TYPE_RECOVERY_TIME;
        } else if (setting == 6 && Complications has :COMPLICATION_TYPE_CALORIES) {
            return Complications.COMPLICATION_TYPE_CALORIES;
        } else if (setting == 7 && Complications has :COMPLICATION_TYPE_BODY_BATTERY) {
            return Complications.COMPLICATION_TYPE_BODY_BATTERY;
        } else if (setting == 8 && Complications has :COMPLICATION_TYPE_BATTERY) {
            return Complications.COMPLICATION_TYPE_BATTERY;
        } else if (setting == 9 && Complications has :COMPLICATION_TYPE_NOTIFICATION_COUNT) {
            return Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT;
        } else if (setting == 10 && Complications has :COMPLICATION_TYPE_CALENDAR_EVENTS) {
            return Complications.COMPLICATION_TYPE_CALENDAR_EVENTS;
        }
        return null;
    }
}

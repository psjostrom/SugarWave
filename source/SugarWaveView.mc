import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.ActivityMonitor;
import Toybox.SensorHistory;

class SugarWaveView extends WatchUi.WatchFace {
    // Detail graph mode (state-driven, no pushView in watch faces)
    hidden var mDetailMode as Boolean = false;
    hidden var mDetailStartSec as Long = 0l;
    const DETAIL_TIMEOUT_SEC = 8;
    const DETAIL_DURATION_MS = 21600000l; // 6 hours

    // Power state
    hidden var mIsHighPower as Boolean = true;

    // Burn-in protection
    hidden var mPixelShiftX as Number = 0;
    hidden var mPixelShiftY as Number = 0;
    hidden var mShiftMinute as Number = -1;

    // CGM data (loaded from Storage)
    hidden var mReadings as Array?;
    hidden var mHistory as Array = [];

    // Settings
    hidden var mBgLow as Float = 4.0f;
    hidden var mBgHigh as Float = 10.0f;
    hidden var mGraphDuration as Number = 60;
    hidden var mComps as Array = [0, 7, 8, 3];
    hidden var mLowPowerEnabled as Boolean = true;

    function initialize() {
        WatchFace.initialize();
    }

    function setDetailMode() as Void {
        mDetailMode = true;
        mDetailStartSec = Time.now().value().toLong();
    }

    function clearDetailMode() as Void {
        mDetailMode = false;
    }

    function isDetailMode() as Boolean {
        return mDetailMode;
    }

    function onLayout(dc as Dc) as Void {
        loadSettings();
    }

    function onShow() as Void {
        loadCgmData();
    }

    function onUpdate(dc as Dc) as Void {
        loadSettings();
        loadCgmData();
        watchdogBgService();

        // Detail graph mode with auto-revert
        if (mDetailMode) {
            var elapsed = Time.now().value().toLong() - mDetailStartSec;
            if (elapsed >= DETAIL_TIMEOUT_SEC) {
                mDetailMode = false;
            } else {
                drawDetailGraph(dc);
                return;
            }
        }

        if (mIsHighPower || !mLowPowerEnabled) {
            drawHighPower(dc);
        } else {
            drawLowPower(dc);
        }
    }

    // Re-register background service if it hasn't fired in 10+ minutes
    hidden function watchdogBgService() as Void {
        try {
            if (!(Toybox.System has :ServiceDelegate)) {
                return;
            }
            if (!System.getDeviceSettings().phoneConnected) {
                return;
            }
            var lastTime = Background.getLastTemporalEventTime();
            if (
                lastTime == null ||
                lastTime.value() < Time.now().value() - 600
            ) {
                Background.registerForTemporalEvent(Time.now());
            }
        } catch (ex) {}
    }

    function onExitSleep() as Void {
        mIsHighPower = true;
    }

    function onEnterSleep() as Void {
        mIsHighPower = false;
        mDetailMode = false;
    }

    // ── Settings ──

    hidden function loadSettings() as Void {
        var low = Application.Properties.getValue("bgLow");
        if (low != null && low instanceof Number) {
            mBgLow = (low as Number).toFloat() / 10.0f;
        }
        var high = Application.Properties.getValue("bgHigh");
        if (high != null && high instanceof Number) {
            mBgHigh = (high as Number).toFloat() / 10.0f;
        }
        var dur = Application.Properties.getValue("graphDuration");
        if (dur != null && dur instanceof Number) {
            mGraphDuration = dur as Number;
        }
        for (var i = 0; i < 4; i++) {
            var val = Application.Properties.getValue(
                "comp" + (i + 1).toString()
            );
            if (val != null && val instanceof Number) {
                mComps[i] = val as Number;
            }
        }
        var lpm = Application.Properties.getValue("lowPowerMode");
        if (lpm != null && lpm instanceof Number) {
            mLowPowerEnabled = (lpm as Number) == 0;
        }
    }

    // ── CGM Data Loading ──

    hidden function loadCgmData() as Void {
        var raw = Application.Storage.getValue("cgmReadings");
        if (raw == null || !(raw instanceof Array)) {
            mReadings = null;
            mHistory = [];
            return;
        }
        mReadings = raw as Array;
        buildHistory();
    }

    hidden function buildHistory() as Void {
        mHistory = [];
        if (mReadings == null) {
            return;
        }
        for (var i = 0; i < mReadings.size(); i++) {
            var r = mReadings[i] as Dictionary;
            var sgv = r.hasKey("sgv") ? r["sgv"] : null;
            var date = r.hasKey("date") ? r["date"] : null;
            if (sgv == null || date == null) {
                continue;
            }
            var bg = Conversions.mgdlToMmol(Conversions.parseFloat(sgv));
            var time = Conversions.parseLong(date);
            mHistory.add({ :bg => bg, :time => time });
        }
    }

    // ── High-Power Rendering ──
    // Layout (top to bottom):
    //   Zone 1: Time (22%) + Date (32%)
    //   Zone 2: Complications (40%) — icons + colored values
    //   Zone 3: Graph (50-73%) — retrowave grid, swapped above CGM
    //   Zone 4: CGM data (82%) — BG + arrow + delta + age

    hidden function drawHighPower(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        drawTimeAndDate(dc, w, h);
        drawComplications(dc, w, h);
        drawGraph(dc, w, h);
        drawCgmData(dc, w, h);
    }

    // ── Zone 1: Time + Date (stacked tight) ──

    hidden function drawTimeAndDate(
        dc as Dc,
        w as Number,
        h as Number
    ) as Void {
        var clockTime = System.getClockTime();
        var hours = clockTime.hour;
        if (!System.getDeviceSettings().is24Hour) {
            if (hours == 0) {
                hours = 12;
            } else if (hours > 12) {
                hours = hours - 12;
            }
        }
        var timeStr = hours.toString() + ":" + clockTime.min.format("%02d");

        var cx = w / 2;
        var timeCy = (h * 0.20f).toNumber();

        NeonRenderer.drawGlowText(
            dc,
            cx,
            timeCy,
            Graphics.FONT_NUMBER_MEDIUM,
            timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER,
            Conversions.COLOR_NEON_CYAN,
            Conversions.COLOR_DIM_CYAN
        );

        // Date above time
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateStr =
            info.day_of_week.substring(0, 3) + " " + info.day.format("%d");
        dc.setColor(Conversions.COLOR_DATE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx,
            (h * 0.06f).toNumber(),
            Graphics.FONT_XTINY,
            dateStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    // ── Zone 2: Complications ──
    // Each complication has a vector icon + colored value.
    // Per-type colors for instant visual distinction.

    hidden function drawComplications(
        dc as Dc,
        w as Number,
        h as Number
    ) as Void {
        var cy = (h * 0.38f).toNumber();
        var numComps = mComps.size();

        // Chord width at this y-position
        var r = w / 2;
        var dy = cy - r;
        var absDy = dy < 0 ? -dy : dy;
        var chord = 2.0f * Math.sqrt((r * r - absDy * absDy).toFloat());
        var usableW = (chord * 0.92f).toNumber();
        var startX = (w - usableW) / 2;
        var spacing = usableW / numComps;

        for (var i = 0; i < numComps; i++) {
            var x = startX + spacing / 2 + i * spacing;
            var compType = mComps[i] as Number;
            var value = getCompValue(compType);
            var color = getCompColor(compType);

            // Draw vector icon above value — more vertical gap
            drawCompIcon(dc, x, cy - 14, compType, color);

            // Truncate long values to fit slot
            var maxW = spacing - 6;
            while (
                dc.getTextWidthInPixels(value, Graphics.FONT_TINY) > maxW &&
                value.length() > 2
            ) {
                value = value.substring(0, value.length() - 1);
            }

            // Value below icon
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                x,
                cy + 14,
                Graphics.FONT_TINY,
                value,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }

    // Draw a small vector icon for each complication type
    hidden function drawCompIcon(
        dc as Dc,
        cx as Number,
        cy as Number,
        compType as Number,
        color as Number
    ) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var s = 6; // icon half-size

        if (compType == 0) {
            // Steps: shoe/footstep — two small vertical bars
            dc.fillRectangle(cx - 4, cy - s, 3, s * 2);
            dc.fillRectangle(cx + 1, cy - s + 3, 3, s * 2 - 3);
        } else if (compType == 1) {
            // Floors: stairs — 3 ascending steps
            dc.fillRectangle(cx - 5, cy + 2, 4, 4);
            dc.fillRectangle(cx - 1, cy - 2, 4, 4);
            dc.fillRectangle(cx + 3, cy - 6, 4, 4);
        } else if (compType == 2) {
            // HR: heart shape
            dc.fillCircle(cx - 3, cy - 2, 3);
            dc.fillCircle(cx + 3, cy - 2, 3);
            dc.fillPolygon([
                [cx - 6, cy],
                [cx, cy + 6],
                [cx + 6, cy],
            ]);
        } else if (compType == 3) {
            // Temperature: thermometer — vertical bar with circle at bottom
            dc.fillRectangle(cx - 2, cy - s, 4, s + 2);
            dc.fillCircle(cx, cy + 4, 4);
        } else if (compType == 4) {
            // Stress: zigzag line
            dc.setPenWidth(2);
            dc.drawLine(cx - 6, cy, cx - 2, cy - 5);
            dc.drawLine(cx - 2, cy - 5, cx + 2, cy + 5);
            dc.drawLine(cx + 2, cy + 5, cx + 6, cy);
            dc.setPenWidth(1);
        } else if (compType == 5) {
            // Recovery: clock/timer — circle with hand
            dc.setPenWidth(2);
            dc.drawCircle(cx, cy, s);
            dc.drawLine(cx, cy, cx + 4, cy - 3);
            dc.setPenWidth(1);
        } else if (compType == 6) {
            // Calories: flame
            dc.fillPolygon([
                [cx, cy - s],
                [cx + 4, cy + 2],
                [cx + 2, cy + s],
                [cx, cy + 3],
                [cx - 2, cy + s],
                [cx - 4, cy + 2],
            ]);
        } else if (compType == 7) {
            // Body Battery: lightning bolt
            dc.fillPolygon([
                [cx + 1, cy - s],
                [cx - 3, cy + 1],
                [cx, cy + 1],
                [cx - 1, cy + s],
                [cx + 3, cy - 1],
                [cx, cy - 1],
            ]);
        } else if (compType == 8) {
            // Watch Battery: battery outline with fill
            dc.drawRectangle(cx - 5, cy - 3, 10, 7);
            dc.fillRectangle(cx + 5, cy - 1, 2, 3);
            dc.fillRectangle(cx - 4, cy - 2, 6, 5);
        } else if (compType == 9) {
            // Notifications: envelope
            dc.drawRectangle(cx - 5, cy - 3, 11, 8);
            dc.drawLine(cx - 5, cy - 3, cx, cy + 1);
            dc.drawLine(cx + 5, cy - 3, cx, cy + 1);
        }
    }

    // Per-type complication colors — all WCAG AA+ on black (≥4.5:1)
    hidden function getCompColor(compType as Number) as Number {
        if (compType == 0) {
            return 0x00ffff;
        } // Steps: cyan (16.7:1)
        if (compType == 1) {
            return 0x00ffff;
        } // Floors: cyan
        if (compType == 2) {
            return 0xFF66AA;
        } // HR: hot pink (7.7:1)
        if (compType == 3) {
            return 0xff8844;
        } // Temp: warm orange (6.4:1)
        if (compType == 4) {
            return 0xffdd00;
        } // Stress: yellow (17.1:1)
        if (compType == 5) {
            return 0xCC77FF;
        } // Recovery: bright purple (7.6:1)
        if (compType == 6) {
            return 0xff8844;
        } // Calories: warm orange
        if (compType == 7) {
            return 0x55ff55;
        } // Body Battery: green (12.2:1)
        if (compType == 8) {
            return 0xffdd00;
        } // Watch Battery: yellow
        if (compType == 9) {
            return 0xCC77FF;
        } // Notifications: bright purple (7.6:1)
        return 0xcccccc;
    }

    // ── Zone 3: Graph (now in middle, before CGM data) ──

    hidden function drawGraph(dc as Dc, w as Number, h as Number) as Void {
        var graphY = (h * 0.48f).toNumber();
        var graphH = (h * 0.28f).toNumber();

        // Chord-based horizontal padding — extra 4% inset
        var r = w / 2;
        var midY = graphY + graphH / 2;
        var dy = midY - r;
        var absDy = dy < 0 ? -dy : dy;
        var chord = 2.0f * Math.sqrt((r * r - absDy * absDy).toFloat());
        var padX = ((w - chord) / 2 + w * 0.04f).toNumber();

        // Retrowave sun — partially set behind the grid horizon
        var sunRadius = (h * 0.08f).toNumber();
        NeonRenderer.drawSun(dc, w / 2, graphY + sunRadius / 3, sunRadius);

        var graphW = w - 2 * padX;
        GraphRenderer.draw(
            dc,
            padX,
            graphY,
            graphW,
            graphH,
            mHistory,
            mGraphDuration,
            mBgLow,
            mBgHigh
        );
    }

    // ── Detail Graph (full-screen, triggered by tap on graph zone) ──

    hidden function drawDetailGraph(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var r = w / 2;
        var rSq = r * r;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ── Header: BG + delta + age + prediction ──
        var headerY = (h * 0.12f).toNumber();
        drawDetailHeader(dc, w, h, headerY);

        // ── Graph area — below header, above X-axis labels ──
        var graphY = (h * 0.26f).toNumber();
        var graphBottom = (h * 0.84f).toNumber();
        var graphH = graphBottom - graphY;

        // Chord widths at top and bottom edges of graph
        var dyTop = graphY - r;
        var chordTop = 2.0f * Math.sqrt((rSq - dyTop * dyTop).toFloat());
        var dyBot = graphBottom - r;
        var chordBot = 2.0f * Math.sqrt((rSq - dyBot * dyBot).toFloat());
        var minChord = chordTop < chordBot ? chordTop : chordBot;

        // Reserve left space for Y-axis labels
        var totalW = (minChord * 0.92f).toNumber();
        var labelReserve = 32;
        var graphW = totalW - labelReserve;
        var graphX = (w - totalW) / 2 + labelReserve;

        // Retrowave grid background
        NeonRenderer.drawPerspectiveGrid(
            dc,
            graphX,
            graphY,
            graphW,
            graphH,
            Conversions.COLOR_GRID
        );

        // Y-axis scaling — dynamic, expands to fit data
        var yMin = mBgLow - 0.5f;
        var yMax = mBgHigh + 0.5f;
        for (var i = 0; i < mHistory.size(); i++) {
            var bg = (mHistory[i] as Dictionary)[:bg] as Float;
            if (bg > 0.0f) {
                if (bg < yMin) {
                    yMin = bg - 0.5f;
                }
                if (bg > yMax) {
                    yMax = bg + 0.5f;
                }
            }
        }
        yMin = yMin.toNumber().toFloat();
        if (yMin < Conversions.GRAPH_Y_MIN) {
            yMin = Conversions.GRAPH_Y_MIN;
        }
        yMax = (yMax.toNumber() + 1).toFloat();
        if (yMax > Conversions.GRAPH_Y_MAX) {
            yMax = Conversions.GRAPH_Y_MAX;
        }
        var yRange = yMax - yMin;

        // Low zone fill
        var lowLineY = GraphRenderer.mmolToPixelY(
            mBgLow,
            graphY,
            graphH,
            yMin,
            yRange
        );
        dc.setColor(
            Conversions.COLOR_GRAPH_LOW_ZONE,
            Graphics.COLOR_TRANSPARENT
        );
        dc.fillRectangle(graphX, lowLineY, graphW, graphY + graphH - lowLineY);

        // Reference lines
        dc.setPenWidth(1);
        dc.setColor(Conversions.COLOR_LOW, Graphics.COLOR_TRANSPARENT);
        GraphRenderer.drawDashedLine(
            dc,
            graphX,
            lowLineY,
            graphX + graphW,
            lowLineY,
            8,
            4
        );

        var highLineY = GraphRenderer.mmolToPixelY(
            mBgHigh,
            graphY,
            graphH,
            yMin,
            yRange
        );
        dc.setColor(
            Conversions.COLOR_GRAPH_HIGH_LINE,
            Graphics.COLOR_TRANSPARENT
        );
        GraphRenderer.drawDashedLine(
            dc,
            graphX,
            highLineY,
            graphX + graphW,
            highLineY,
            8,
            4
        );

        // Y-axis labels — adaptive step: 1 if range ≤ 8, 2 otherwise
        var labelFont = Graphics.FONT_XTINY;
        var labelX = graphX - 3;
        var yStep = yRange > 8.0f ? 2.0f : 1.0f;
        var mmolVal = ((yMin / yStep).toNumber() + 1).toFloat() * yStep;
        while (mmolVal < yMax) {
            var ly = GraphRenderer.mmolToPixelY(
                mmolVal,
                graphY,
                graphH,
                yMin,
                yRange
            );
            var ldx = labelX - 28 - r;
            var ldy = ly - r;
            if (ldx * ldx + ldy * ldy < rSq) {
                dc.setColor(
                    Conversions.COLOR_NEON_PURPLE,
                    Graphics.COLOR_TRANSPARENT
                );
                dc.drawText(
                    labelX,
                    ly,
                    labelFont,
                    mmolVal.format("%.0f"),
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
                );
            }
            mmolVal += yStep;
        }

        // Time setup — dynamic window from actual data span
        var newestTime = Time.now().value().toLong() * 1000l;
        var detailDurationMs = DETAIL_DURATION_MS;
        if (mHistory.size() > 1) {
            var oldest = (mHistory[mHistory.size() - 1] as Dictionary)[:time] as Long;
            var newest = (mHistory[0] as Dictionary)[:time] as Long;
            var span = newest - oldest;
            if (span > 0 && span < detailDurationMs) {
                // Pad by 10% on each side for breathing room
                detailDurationMs = span + span / 5;
                if (detailDurationMs < 600000l) { detailDurationMs = 600000l; } // min 10 min
            }
        }
        var oldestTime = newestTime - detailDurationMs;

        // X-axis time labels — tighter radius to prevent edge overflow
        var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var currentHour = nowInfo.hour as Number;
        var minMs = (nowInfo.min as Number).toLong() * 60000l;
        var secMs = (nowInfo.sec as Number).toLong() * 1000l;
        var xLabelY = graphBottom + 8;
        var rInset = r - 24;
        var rInsetSq = rInset * rInset;

        var maxHoursBack = (detailDurationMs / 3600000l).toNumber() + 1;
        for (var hOffset = -maxHoursBack; hOffset <= 0; hOffset++) {
            var labelHour = currentHour + hOffset;
            while (labelHour < 0) {
                labelHour += 24;
            }
            labelHour = labelHour % 24;

            var hourTimeMs =
                newestTime + hOffset.toLong() * 3600000l - minMs - secMs;
            if (hourTimeMs < oldestTime || hourTimeMs > newestTime) {
                continue;
            }

            var lx = GraphRenderer.timeToPixelX(
                hourTimeMs,
                graphX,
                graphW,
                newestTime,
                detailDurationMs
            );
            var xdx = lx - r;
            var xdy = xLabelY - r;
            if (xdx * xdx + xdy * xdy < rInsetSq) {
                dc.setColor(
                    Conversions.COLOR_NEON_PURPLE,
                    Graphics.COLOR_TRANSPARENT
                );
                dc.drawText(
                    lx,
                    xLabelY,
                    labelFont,
                    labelHour.format("%02d"),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );
            }
        }

        // Plot data points
        if (mHistory.size() == 0) {
            return;
        }

        var points = [] as Array;
        for (var i = mHistory.size() - 1; i >= 0; i--) {
            var entry = mHistory[i] as Dictionary;
            var t = entry[:time] as Long;
            if (t < oldestTime) {
                continue;
            }
            var bg = entry[:bg] as Float;
            var px = GraphRenderer.timeToPixelX(
                t,
                graphX,
                graphW,
                newestTime,
                detailDurationMs
            );
            var py = GraphRenderer.mmolToPixelY(
                bg,
                graphY,
                graphH,
                yMin,
                yRange
            );
            points.add({ :px => px, :py => py, :bg => bg });
        }

        if (points.size() == 0) {
            return;
        }

        // Adaptive glow — scale by point density
        var ds = 1.0f;
        if (points.size() > 1) {
            var totalDx = 0;
            for (var i = 1; i < points.size(); i++) {
                var dx = (points[i] as Dictionary)[:px] as Number - (points[i-1] as Dictionary)[:px] as Number;
                if (dx < 0) { dx = -dx; }
                totalDx += dx;
            }
            var avgSpacing = totalDx.toFloat() / (points.size() - 1);
            ds = avgSpacing / 12.0f;
            if (ds > 1.0f) { ds = 1.0f; }
            if (ds < 0.3f) { ds = 0.3f; }
        }

        var dLineHalo = 1 + (4.0f * ds).toNumber();
        var dLineBloom = 1 + (2.0f * ds).toNumber();
        var dDotR = (2.0f * ds).toNumber();
        if (dDotR < 1) { dDotR = 1; }
        var dHaloOuter = (5.0f * ds).toNumber();
        if (dHaloOuter < dDotR + 1) { dHaloOuter = dDotR + 1; }
        var dHaloInner = (3.0f * ds).toNumber();
        if (dHaloInner < dDotR) { dHaloInner = dDotR; }

        // Neon glow connecting lines
        dc.setAntiAlias(true);
        var lr = 0xff;
        var lg = 0x00;
        var lb = 0x66;

        dc.setStroke(Graphics.createColor(25, lr, lg, lb));
        dc.setPenWidth(dLineHalo);
        for (var i = 1; i < points.size(); i++) {
            var prev = points[i - 1] as Dictionary;
            var curr = points[i] as Dictionary;
            dc.drawLine(
                prev[:px] as Number,
                prev[:py] as Number,
                curr[:px] as Number,
                curr[:py] as Number
            );
        }
        dc.setStroke(Graphics.createColor(60, lr, lg, lb));
        dc.setPenWidth(dLineBloom);
        for (var i = 1; i < points.size(); i++) {
            var prev = points[i - 1] as Dictionary;
            var curr = points[i] as Dictionary;
            dc.drawLine(
                prev[:px] as Number,
                prev[:py] as Number,
                curr[:px] as Number,
                curr[:py] as Number
            );
        }
        dc.setStroke(Graphics.createColor(255, lr, lg, lb));
        dc.setPenWidth(1);
        for (var i = 1; i < points.size(); i++) {
            var prev = points[i - 1] as Dictionary;
            var curr = points[i] as Dictionary;
            dc.drawLine(
                prev[:px] as Number,
                prev[:py] as Number,
                curr[:px] as Number,
                curr[:py] as Number
            );
        }
        dc.setPenWidth(1);

        // Neon dots with glow halos
        for (var i = 0; i < points.size(); i++) {
            var pt = points[i] as Dictionary;
            var bg = pt[:bg] as Float;
            var dotColor = Conversions.graphDotColor(bg, mBgLow, mBgHigh);
            var dr = (dotColor >> 16) & 0xff;
            var dg = (dotColor >> 8) & 0xff;
            var db = dotColor & 0xff;
            dc.setFill(Graphics.createColor(25, dr, dg, db));
            dc.fillCircle(pt[:px] as Number, pt[:py] as Number, dHaloOuter);
            dc.setFill(Graphics.createColor(80, dr, dg, db));
            dc.fillCircle(pt[:px] as Number, pt[:py] as Number, dHaloInner);
            dc.setFill(Graphics.createColor(255, dr, dg, db));
            dc.fillCircle(pt[:px] as Number, pt[:py] as Number, dDotR);
        }
        dc.setAntiAlias(false);
    }

    // ── Detail header: BG + delta + age (row 1) + prediction (row 2) ──
    hidden function drawDetailHeader(
        dc as Dc,
        w as Number,
        h as Number,
        cy as Number
    ) as Void {
        if (mReadings == null || mReadings.size() == 0) {
            return;
        }

        var latest = mReadings[0] as Dictionary;
        var bgMgdl = Conversions.parseFloat(latest["sgv"]);
        var bgMmol = Conversions.mgdlToMmol(bgMgdl);
        var bgText = bgMmol.format("%.1f");
        var bgCol = Conversions.bgColor(bgMmol, mBgLow, mBgHigh);

        var deltaMgdl = Conversions.parseFloat(latest["delta"]);
        var deltaMmol = Conversions.mgdlToMmol(deltaMgdl);
        var deltaText = Conversions.formatDelta(deltaMmol);
        var direction = Conversions.directionFromString(latest["direction"]);

        var lastTime = latest.hasKey("date")
            ? Conversions.parseLong(latest["date"])
            : 0l;
        var minutesSince =
            lastTime > 0
                ? (
                      (Time.now().value().toLong() - lastTime / 1000) /
                      60
                  ).toNumber()
                : -1;
        var ageText = minutesSince >= 0 ? minutesSince.toString() + "'" : "-";

        // Chord-aware layout
        var r = w / 2;
        var dyH = cy - r;
        var chord = 2.0f * Math.sqrt((r * r - dyH * dyH).toFloat());
        var maxW = (chord * 0.88f).toNumber();

        // Row 1: [arrow] [BG] [delta] [age]
        var arrowSize = 16;
        var gap = 10;
        var smallFont = Graphics.FONT_SMALL;
        var tinyFont = Graphics.FONT_TINY;
        var bgW = dc.getTextWidthInPixels(bgText, smallFont);
        var deltaW = dc.getTextWidthInPixels(deltaText, tinyFont);
        var ageW = dc.getTextWidthInPixels(ageText, tinyFont);
        var totalW = arrowSize + gap + bgW + gap + deltaW + gap + ageW;

        // Shrink gaps if too wide for chord
        if (totalW > maxW) {
            gap = (maxW - arrowSize - bgW - deltaW - ageW) / 3;
            if (gap < 2) {
                gap = 2;
            }
            totalW = arrowSize + gap + bgW + gap + deltaW + gap + ageW;
        }

        var x = (w - totalW) / 2;

        ArrowRenderer.draw(
            dc,
            x + arrowSize / 2,
            cy,
            arrowSize,
            direction,
            bgCol
        );
        x += arrowSize + gap;

        dc.setColor(bgCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            cy,
            smallFont,
            bgText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        x += bgW + gap;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            cy,
            tinyFont,
            deltaText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        x += deltaW + gap;

        dc.setColor(
            Conversions.staleColor(minutesSince),
            Graphics.COLOR_TRANSPARENT
        );
        dc.drawText(
            x,
            cy,
            tinyFont,
            ageText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Row 2: Time-to-threshold prediction (if ≤30 min)
        // deltaMmol is per minute
        var deltaMmolPerMin = deltaMmol;
        var predText = null as String?;
        var predColor = 0;

        if (deltaMmolPerMin < -0.01f) {
            if (bgMmol > mBgHigh) {
                var minTo = ((bgMmol - mBgHigh) / -deltaMmolPerMin).toNumber();
                if (minTo > 0 && minTo <= 30) {
                    predText =
                        mBgHigh.format("%.1f") +
                        " in " +
                        minTo.toString() +
                        "'";
                    predColor = Conversions.COLOR_HIGH;
                }
            } else if (bgMmol > mBgLow) {
                var minTo = ((bgMmol - mBgLow) / -deltaMmolPerMin).toNumber();
                if (minTo > 0 && minTo <= 30) {
                    predText =
                        mBgLow.format("%.1f") + " in " + minTo.toString() + "'";
                    predColor = Conversions.COLOR_LOW;
                }
            }
        } else if (deltaMmolPerMin > 0.01f) {
            if (bgMmol < mBgLow) {
                var minTo = ((mBgLow - bgMmol) / deltaMmolPerMin).toNumber();
                if (minTo > 0 && minTo <= 30) {
                    predText =
                        mBgLow.format("%.1f") + " in " + minTo.toString() + "'";
                    predColor = Conversions.COLOR_LOW;
                }
            } else if (bgMmol < mBgHigh) {
                var minTo = ((mBgHigh - bgMmol) / deltaMmolPerMin).toNumber();
                if (minTo > 0 && minTo <= 30) {
                    predText =
                        mBgHigh.format("%.1f") +
                        " in " +
                        minTo.toString() +
                        "'";
                    predColor = Conversions.COLOR_HIGH;
                }
            }
        }

        if (predText != null) {
            var predY = (h * 0.22f).toNumber();
            dc.setColor(predColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                w / 2,
                predY,
                tinyFont,
                predText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }

    // ── Zone 4: CGM Data (now below graph) ──

    hidden function drawCgmData(dc as Dc, w as Number, h as Number) as Void {
        var cy = (h * 0.84f).toNumber();

        if (mReadings == null || mReadings.size() == 0) {
            var errVal = Application.Storage.getValue("cgmError");
            var errText = "---";
            if (errVal != null && errVal instanceof Number) {
                errText = "E:" + errVal.toString();
            }
            NeonRenderer.drawGlowText(
                dc,
                w / 2,
                cy,
                Graphics.FONT_LARGE,
                errText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER,
                Conversions.COLOR_DATE,
                Conversions.COLOR_DIM_PURPLE
            );
            return;
        }

        var latest = mReadings[0] as Dictionary;
        var bgMgdl = Conversions.parseFloat(latest["sgv"]);
        var bgMmol = Conversions.mgdlToMmol(bgMgdl);
        var bgText = bgMmol.format("%.1f");
        var bgCol = Conversions.bgColor(bgMmol, mBgLow, mBgHigh);

        var deltaMgdl = Conversions.parseFloat(latest["delta"]);
        var deltaMmol = Conversions.mgdlToMmol(deltaMgdl);
        var deltaText = Conversions.formatDelta(deltaMmol);
        var direction = Conversions.directionFromString(latest["direction"]);

        var lastTime = latest.hasKey("date")
            ? Conversions.parseLong(latest["date"])
            : 0l;
        var minutesSince =
            lastTime > 0
                ? (
                      (Time.now().value().toLong() - lastTime / 1000) /
                      60
                  ).toNumber()
                : -1;
        var ageText = minutesSince >= 0 ? minutesSince.toString() + "'" : "-";
        var ageColor = Conversions.staleColor(minutesSince);

        // Layout: [arrow] gap [BG] gap [delta] gap [age]
        var arrowSize = (h * 0.06f).toNumber();
        var gap = (w * 0.03f).toNumber();

        var bgFont = Graphics.FONT_LARGE;
        var smallFont = Graphics.FONT_SMALL;
        var bgW = dc.getTextWidthInPixels(bgText, bgFont);
        var deltaW = dc.getTextWidthInPixels(deltaText, smallFont);
        var ageW = dc.getTextWidthInPixels(ageText, smallFont);
        var totalW = arrowSize + gap + bgW + gap + deltaW + gap + ageW;

        // Chord-aware: ensure we fit within the circle at this Y
        var r = w / 2;
        var dy = cy - r;
        var absDy = dy < 0 ? -dy : dy;
        var chord = 2.0f * Math.sqrt((r * r - absDy * absDy).toFloat());
        var maxW = (chord * 0.90f).toNumber();
        if (totalW > maxW) {
            gap = (maxW - arrowSize - bgW - deltaW - ageW) / 3;
            if (gap < 4) {
                gap = 4;
            }
            totalW = arrowSize + gap + bgW + gap + deltaW + gap + ageW;
        }

        var x = (w - totalW) / 2;

        // Arrow
        ArrowRenderer.draw(
            dc,
            x + arrowSize / 2,
            cy,
            arrowSize,
            direction,
            bgCol
        );
        x += arrowSize + gap;

        // BG value — crisp neon
        var bgX = x;
        dc.setColor(bgCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            cy,
            bgFont,
            bgText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        // Strikethrough when data is stale
        if (minutesSince >= Conversions.STALE_MINUTES) {
            dc.setColor(Conversions.COLOR_STALE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawLine(bgX, cy, bgX + bgW, cy);
            dc.setPenWidth(1);
        }
        x += bgW + gap;

        // Delta — white for max contrast (21:1)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            cy,
            smallFont,
            deltaText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        x += deltaW + gap;

        // Time since — color-coded by staleness
        dc.setColor(ageColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            cy,
            smallFont,
            ageText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    // ── Low-Power / AOD Rendering ──

    hidden function drawLowPower(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        updatePixelShift();
        var sx = mPixelShiftX;
        var sy = mPixelShiftY;

        // Time (thin font, no glow, light gray — 13.1:1 contrast)
        var clockTime = System.getClockTime();
        var hours = clockTime.hour;
        if (!System.getDeviceSettings().is24Hour) {
            if (hours == 0) {
                hours = 12;
            } else if (hours > 12) {
                hours = hours - 12;
            }
        }
        var timeStr = hours.toString() + ":" + clockTime.min.format("%02d");

        dc.setColor(Conversions.COLOR_NEON_CYAN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            w / 2 + sx,
            (h * 0.28f).toNumber() + sy,
            Graphics.FONT_NUMBER_MEDIUM,
            timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // BG value (full-brightness color — small area, pixel shift protects burn-in)
        if (mReadings != null && mReadings.size() > 0) {
            var latest = mReadings[0] as Dictionary;
            var bgMgdl = Conversions.parseFloat(latest["sgv"]);
            var bgMmol = Conversions.mgdlToMmol(bgMgdl);
            var bgText = bgMmol.format("%.1f");
            var bgCol = Conversions.bgColor(bgMmol, mBgLow, mBgHigh);

            var lastTime = latest.hasKey("date")
                ? Conversions.parseLong(latest["date"])
                : 0l;
            var minutesSince =
                lastTime > 0
                    ? (
                          (Time.now().value().toLong() - lastTime / 1000) /
                          60
                      ).toNumber()
                    : -1;
            var ageText =
                minutesSince >= 0 ? minutesSince.toString() + "'" : "-";

            var deltaMgdl = Conversions.parseFloat(latest["delta"]);
            var deltaText = Conversions.formatDelta(
                Conversions.mgdlToMmol(deltaMgdl)
            );

            // BG — full color
            var bgCy = (h * 0.43f).toNumber() + sy;
            dc.setColor(bgCol, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                w / 2 + sx,
                bgCy,
                Graphics.FONT_LARGE,
                bgText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            // Strikethrough when stale
            if (minutesSince >= Conversions.STALE_MINUTES) {
                var bgW = dc.getTextWidthInPixels(bgText, Graphics.FONT_LARGE);
                dc.setColor(
                    Conversions.COLOR_STALE,
                    Graphics.COLOR_TRANSPARENT
                );
                dc.setPenWidth(3);
                dc.drawLine(
                    w / 2 - bgW / 2 + sx,
                    bgCy,
                    w / 2 + bgW / 2 + sx,
                    bgCy
                );
                dc.setPenWidth(1);
            }

            // Delta + age below BG — light gray for readability
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                w / 2 + sx,
                (h * 0.53f).toNumber() + sy,
                Graphics.FONT_TINY,
                deltaText + "  " + ageText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // Graph (simplified, dimmed, no perspective grid)
        if (mHistory.size() > 0) {
            var graphY = (h * 0.59f).toNumber() + sy;
            var graphH = (h * 0.23f).toNumber();
            var r = w / 2;
            var midY = graphY + graphH / 2 - sy;
            var dy = midY - r;
            var absDy = dy < 0 ? -dy : dy;
            var chord = 2.0f * Math.sqrt((r * r - absDy * absDy).toFloat());
            var padX = ((w - chord) / 2 + w * 0.06f).toNumber();

            GraphRenderer.drawAOD(
                dc,
                padX + sx,
                graphY,
                w - 2 * padX,
                graphH,
                mHistory,
                mGraphDuration,
                mBgLow,
                mBgHigh
            );
        }

        // Steps below graph
        var stepsText = getSteps();
        if (!stepsText.equals("--")) {
            dc.setColor(0xCC77FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                w / 2 + sx,
                (h * 0.89f).toNumber() + sy,
                Graphics.FONT_MEDIUM,
                stepsText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }

    hidden function updatePixelShift() as Void {
        var clockTime = System.getClockTime();
        if (clockTime.min == mShiftMinute) {
            return;
        }
        mShiftMinute = clockTime.min;

        var phase = clockTime.min % 4;
        if (phase == 0) {
            mPixelShiftX = 0;
            mPixelShiftY = 0;
        } else if (phase == 1) {
            mPixelShiftX = 3;
            mPixelShiftY = 0;
        } else if (phase == 2) {
            mPixelShiftX = 3;
            mPixelShiftY = 3;
        } else {
            mPixelShiftX = 0;
            mPixelShiftY = 3;
        }
    }

    // ── Complication Data Retrieval ──

    hidden function getCompValue(type as Number) as String {
        if (type == 0) {
            return getSteps();
        }
        if (type == 1) {
            return getFloors();
        }
        if (type == 2) {
            return getHeartRate();
        }
        if (type == 3) {
            return getTemperature();
        }
        if (type == 4) {
            return getStress();
        }
        if (type == 5) {
            return getRecovery();
        }
        if (type == 6) {
            return getCalories();
        }
        if (type == 7) {
            return getBodyBattery();
        }
        if (type == 8) {
            return getBatteryLevel();
        }
        if (type == 9) {
            return getNotifications();
        }
        return "--";
    }

    hidden function getSteps() as String {
        var steps = null as Number?;
        if (Toybox has :ActivityMonitor) {
            var info = ActivityMonitor.getInfo();
            steps = info.steps;
        }
        if (steps == null && Toybox has :Complications) {
            try {
                var comp = Toybox.Complications.getComplication(
                    new Toybox.Complications.Id(
                        Toybox.Complications.COMPLICATION_TYPE_STEPS
                    )
                );
                if (comp.value != null) {
                    // API returns float in thousands for large values (e.g. 5.382 = 5382)
                    var fval = comp.value.toFloat();
                    var intVal = fval.toNumber();
                    var frac = fval - intVal;
                    if (frac > 0.001f || frac < -0.001f) {
                        steps = (fval * 1000).toNumber();
                    } else {
                        steps = intVal;
                    }
                }
            } catch (ex) {}
        }
        if (steps == null) {
            return "--";
        }
        return formatCompact(steps);
    }

    // Format large numbers compactly: 12345 → "12.3k"
    hidden function formatCompact(val as Number) as String {
        if (val >= 10000) {
            return (
                (val / 1000).toString() +
                "." +
                ((val % 1000) / 100).toString() +
                "k"
            );
        }
        return val.toString();
    }

    hidden function getFloors() as String {
        if (Toybox has :Complications) {
            try {
                var comp = Toybox.Complications.getComplication(
                    new Toybox.Complications.Id(
                        Toybox.Complications.COMPLICATION_TYPE_FLOORS_CLIMBED
                    )
                );
                if (comp.value != null) {
                    return comp.value.toNumber().toString();
                }
            } catch (ex) {}
        }
        if (Toybox has :ActivityMonitor) {
            var info = ActivityMonitor.getInfo();
            if (info.floorsClimbed != null) {
                return info.floorsClimbed.toString();
            }
        }
        return "--";
    }

    hidden function getHeartRate() as String {
        if (Toybox has :Complications) {
            try {
                var comp = Toybox.Complications.getComplication(
                    new Toybox.Complications.Id(
                        Toybox.Complications.COMPLICATION_TYPE_HEART_RATE
                    )
                );
                if (comp.value != null) {
                    return comp.value.toNumber().toString();
                }
            } catch (ex) {}
        }
        if (
            Toybox has :SensorHistory &&
            SensorHistory has :getHeartRateHistory
        ) {
            var iter = SensorHistory.getHeartRateHistory({});
            var sample = iter.next();
            if (
                sample != null &&
                sample.data != null &&
                sample.data != ActivityMonitor.INVALID_HR_SAMPLE
            ) {
                return sample.data.toNumber().toString();
            }
        }
        return "--";
    }

    hidden function getTemperature() as String {
        if (Toybox has :Complications) {
            try {
                var comp = Toybox.Complications.getComplication(
                    new Toybox.Complications.Id(
                        Toybox.Complications
                            .COMPLICATION_TYPE_CURRENT_TEMPERATURE
                    )
                );
                if (comp.value != null) {
                    return (comp.value + 0.5).toNumber().toString() + "\u00B0";
                }
            } catch (ex) {}
        }
        if (
            Toybox has :SensorHistory &&
            SensorHistory has :getTemperatureHistory
        ) {
            var iter = SensorHistory.getTemperatureHistory({});
            var sample = iter.next();
            if (sample != null && sample.data != null) {
                return (sample.data + 0.5).toNumber().toString() + "\u00B0";
            }
        }
        return "--";
    }

    hidden function getStress() as String {
        if (Toybox has :Complications) {
            try {
                var comp = Toybox.Complications.getComplication(
                    new Toybox.Complications.Id(
                        Toybox.Complications.COMPLICATION_TYPE_STRESS
                    )
                );
                if (comp.value != null) {
                    return (comp.value + 0.5).toNumber().toString();
                }
            } catch (ex) {}
        }
        if (Toybox has :SensorHistory && SensorHistory has :getStressHistory) {
            var iter = SensorHistory.getStressHistory({});
            var sample = iter.next();
            if (sample != null && sample.data != null) {
                return (sample.data + 0.5).toNumber().toString();
            }
        }
        return "--";
    }

    hidden function getRecovery() as String {
        if (Toybox has :Complications) {
            try {
                var comp = Toybox.Complications.getComplication(
                    new Toybox.Complications.Id(
                        Toybox.Complications.COMPLICATION_TYPE_RECOVERY_TIME
                    )
                );
                if (comp.value != null) {
                    return (comp.value / 60).toNumber().toString() + "h";
                }
            } catch (ex) {}
        }
        if (Toybox has :ActivityMonitor) {
            var info = ActivityMonitor.getInfo();
            if (info has :timeToRecovery && info.timeToRecovery != null) {
                return info.timeToRecovery.toString() + "h";
            }
        }
        return "--";
    }

    hidden function getCalories() as String {
        var cal = null as Number?;
        if (Toybox has :Complications) {
            try {
                var comp = Toybox.Complications.getComplication(
                    new Toybox.Complications.Id(
                        Toybox.Complications.COMPLICATION_TYPE_CALORIES
                    )
                );
                if (comp.value != null) {
                    cal = comp.value.toNumber();
                }
            } catch (ex) {}
        }
        if (cal == null && Toybox has :ActivityMonitor) {
            var info = ActivityMonitor.getInfo();
            cal = info.calories;
        }
        if (cal == null) {
            return "--";
        }
        return formatCompact(cal);
    }

    hidden function getBodyBattery() as String {
        if (Toybox has :Complications) {
            try {
                var comp = Toybox.Complications.getComplication(
                    new Toybox.Complications.Id(
                        Toybox.Complications.COMPLICATION_TYPE_BODY_BATTERY
                    )
                );
                if (comp.value != null) {
                    return (comp.value + 0.5).toNumber().toString();
                }
            } catch (ex) {}
        }
        if (
            Toybox has :SensorHistory &&
            SensorHistory has :getBodyBatteryHistory
        ) {
            var iter = SensorHistory.getBodyBatteryHistory({});
            var sample = iter.next();
            if (sample != null && sample.data != null) {
                return (sample.data + 0.5).toNumber().toString();
            }
        }
        return "--";
    }

    hidden function getBatteryLevel() as String {
        if (Toybox has :Complications) {
            try {
                var comp = Toybox.Complications.getComplication(
                    new Toybox.Complications.Id(
                        Toybox.Complications.COMPLICATION_TYPE_BATTERY
                    )
                );
                if (comp.value != null) {
                    return comp.value.format("%d") + "%";
                }
            } catch (ex) {}
        }
        var stats = System.getSystemStats();
        if (stats has :battery && stats.battery != null) {
            return stats.battery.format("%d") + "%";
        }
        return "--";
    }

    hidden function getNotifications() as String {
        if (Toybox has :Complications) {
            try {
                var comp = Toybox.Complications.getComplication(
                    new Toybox.Complications.Id(
                        Toybox.Complications
                            .COMPLICATION_TYPE_NOTIFICATION_COUNT
                    )
                );
                if (comp.value != null) {
                    return comp.value.toNumber().toString();
                }
            } catch (ex) {}
        }
        var settings = System.getDeviceSettings();
        if (settings has :notificationCount) {
            return settings.notificationCount.toString();
        }
        return "--";
    }
}

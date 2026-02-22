import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;

module GraphRenderer {

    const DOT_RADIUS = 5;
    const LINE_WIDTH = 2;

    // Draw BG graph overlaid on a retrowave perspective grid.
    // history: Array of {:bg => Float (mmol), :time => Long (unix ms)}, newest first.
    function draw(dc as Dc, x as Number, y as Number, w as Number, h as Number,
                  history as Array, durationMin as Number,
                  bgLow as Float, bgHigh as Float) as Void {

        // Draw perspective grid background
        NeonRenderer.drawPerspectiveGrid(dc, x, y, w, h, Conversions.COLOR_GRID);

        // Y-axis scaling
        var yMin = bgLow - 0.5f;
        var yMax = bgHigh + 0.5f;
        for (var i = 0; i < history.size(); i++) {
            var bg = (history[i] as Dictionary)[:bg] as Float;
            if (bg > 0.0f) {
                if (bg < yMin) { yMin = bg - 0.5f; }
                if (bg > yMax) { yMax = bg + 0.5f; }
            }
        }
        yMin = (yMin.toNumber()).toFloat();
        if (yMin < Conversions.GRAPH_Y_MIN) { yMin = Conversions.GRAPH_Y_MIN; }
        yMax = (yMax.toNumber() + 1).toFloat();
        if (yMax > Conversions.GRAPH_Y_MAX) { yMax = Conversions.GRAPH_Y_MAX; }
        var yRange = yMax - yMin;

        // Low zone fill
        var lowLineY = mmolToPixelY(bgLow, y, h, yMin, yRange);
        dc.setColor(Conversions.COLOR_GRAPH_LOW_ZONE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, lowLineY, w, y + h - lowLineY);

        // Reference lines (dashed neon)
        dc.setPenWidth(1);
        dc.setColor(Conversions.COLOR_LOW, Graphics.COLOR_TRANSPARENT);
        drawDashedLine(dc, x, lowLineY, x + w, lowLineY, 8, 4);

        var highLineY = mmolToPixelY(bgHigh, y, h, yMin, yRange);
        dc.setColor(Conversions.COLOR_GRAPH_HIGH_LINE, Graphics.COLOR_TRANSPARENT);
        drawDashedLine(dc, x, highLineY, x + w, highLineY, 8, 4);

        // Filter and plot data
        if (history.size() == 0) { return; }

        // Use wall clock as right edge so stale data scrolls left
        var newestTime = Time.now().value().toLong() * 1000l;
        var durationMs = durationMin.toLong() * 60000l;
        var oldestTime = newestTime - durationMs;

        var points = [] as Array;
        for (var i = history.size() - 1; i >= 0; i--) {
            var entry = history[i] as Dictionary;
            var t = entry[:time] as Long;
            if (t < oldestTime) { continue; }
            var bg = entry[:bg] as Float;
            var px = timeToPixelX(t, x, w, newestTime, durationMs);
            var py = mmolToPixelY(bg, y, h, yMin, yRange);
            points.add({:px => px, :py => py, :bg => bg});
        }

        if (points.size() == 0) { return; }

        // Connecting lines with neon glow (alpha multi-pass)
        dc.setAntiAlias(true);
        var lr = 0xFF;
        var lg = 0x00;
        var lb = 0x66;
        // Wide dim halo
        dc.setStroke(Graphics.createColor(25, lr, lg, lb));
        dc.setPenWidth(LINE_WIDTH + 10);
        for (var i = 1; i < points.size(); i++) {
            var prev = points[i - 1] as Dictionary;
            var curr = points[i] as Dictionary;
            dc.drawLine(prev[:px] as Number, prev[:py] as Number,
                curr[:px] as Number, curr[:py] as Number);
        }
        // Medium bloom
        dc.setStroke(Graphics.createColor(60, lr, lg, lb));
        dc.setPenWidth(LINE_WIDTH + 4);
        for (var i = 1; i < points.size(); i++) {
            var prev = points[i - 1] as Dictionary;
            var curr = points[i] as Dictionary;
            dc.drawLine(prev[:px] as Number, prev[:py] as Number,
                curr[:px] as Number, curr[:py] as Number);
        }
        // Bright core
        dc.setStroke(Graphics.createColor(255, lr, lg, lb));
        dc.setPenWidth(LINE_WIDTH);
        for (var i = 1; i < points.size(); i++) {
            var prev = points[i - 1] as Dictionary;
            var curr = points[i] as Dictionary;
            dc.drawLine(prev[:px] as Number, prev[:py] as Number,
                curr[:px] as Number, curr[:py] as Number);
        }
        dc.setPenWidth(1);

        // Neon dots with alpha glow halos
        for (var i = 0; i < points.size(); i++) {
            var pt = points[i] as Dictionary;
            var bg = pt[:bg] as Float;
            var dotColor = Conversions.graphDotColor(bg, bgLow, bgHigh);
            var dr = (dotColor >> 16) & 0xFF;
            var dg = (dotColor >> 8) & 0xFF;
            var db = dotColor & 0xFF;
            // Outer halo
            dc.setFill(Graphics.createColor(20, dr, dg, db));
            dc.fillCircle(pt[:px] as Number, pt[:py] as Number, DOT_RADIUS * 3);
            // Inner halo
            dc.setFill(Graphics.createColor(60, dr, dg, db));
            dc.fillCircle(pt[:px] as Number, pt[:py] as Number, DOT_RADIUS * 2);
            // Bright core
            dc.setFill(Graphics.createColor(255, dr, dg, db));
            dc.fillCircle(pt[:px] as Number, pt[:py] as Number, DOT_RADIUS);
        }
        dc.setAntiAlias(false);
    }

    // Simplified AOD graph — no grid, smaller dots, half-brightness colors.
    // Minimal lit pixels for AMOLED burn-in protection.
    function drawAOD(dc as Dc, x as Number, y as Number, w as Number, h as Number,
                     history as Array, durationMin as Number,
                     bgLow as Float, bgHigh as Float) as Void {

        // Y-axis scaling (same logic as draw())
        var yMin = bgLow - 0.5f;
        var yMax = bgHigh + 0.5f;
        for (var i = 0; i < history.size(); i++) {
            var bg = (history[i] as Dictionary)[:bg] as Float;
            if (bg > 0.0f) {
                if (bg < yMin) { yMin = bg - 0.5f; }
                if (bg > yMax) { yMax = bg + 0.5f; }
            }
        }
        yMin = (yMin.toNumber()).toFloat();
        if (yMin < Conversions.GRAPH_Y_MIN) { yMin = Conversions.GRAPH_Y_MIN; }
        yMax = (yMax.toNumber() + 1).toFloat();
        if (yMax > Conversions.GRAPH_Y_MAX) { yMax = Conversions.GRAPH_Y_MAX; }
        var yRange = yMax - yMin;

        // Dimmed reference lines
        var lowLineY = mmolToPixelY(bgLow, y, h, yMin, yRange);
        dc.setPenWidth(1);
        dc.setColor(0x7F2A2A, Graphics.COLOR_TRANSPARENT);
        drawDashedLine(dc, x, lowLineY, x + w, lowLineY, 6, 6);

        var highLineY = mmolToPixelY(bgHigh, y, h, yMin, yRange);
        dc.setColor(0x7F3300, Graphics.COLOR_TRANSPARENT);
        drawDashedLine(dc, x, highLineY, x + w, highLineY, 6, 6);

        // Plot data
        if (history.size() == 0) { return; }

        // Use wall clock as right edge so stale data scrolls left
        var newestTime = Time.now().value().toLong() * 1000l;
        var durationMs = durationMin.toLong() * 60000l;
        var oldestTime = newestTime - durationMs;

        var points = [] as Array;
        for (var i = history.size() - 1; i >= 0; i--) {
            var entry = history[i] as Dictionary;
            var t = entry[:time] as Long;
            if (t < oldestTime) { continue; }
            var bg = entry[:bg] as Float;
            var px = timeToPixelX(t, x, w, newestTime, durationMs);
            var py = mmolToPixelY(bg, y, h, yMin, yRange);
            points.add({:px => px, :py => py, :bg => bg});
        }

        if (points.size() == 0) { return; }

        // Thin connecting lines (dim purple, readable outdoors)
        dc.setPenWidth(1);
        dc.setColor(0x7A00BB, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i < points.size(); i++) {
            var prev = points[i - 1] as Dictionary;
            var curr = points[i] as Dictionary;
            dc.drawLine(
                prev[:px] as Number, prev[:py] as Number,
                curr[:px] as Number, curr[:py] as Number
            );
        }

        // Small dots (radius 3, 75% brightness)
        for (var i = 0; i < points.size(); i++) {
            var pt = points[i] as Dictionary;
            var bg = pt[:bg] as Float;
            var dotColor = Conversions.graphDotColor(bg, bgLow, bgHigh);
            var dimColor = dotColor - ((dotColor >> 2) & 0x3F3F3F);
            dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(pt[:px] as Number, pt[:py] as Number, 3);
        }
    }

    function mmolToPixelY(mmol as Float, areaY as Number, areaH as Number,
                                  yMin as Float, yRange as Float) as Number {
        var ratio = (mmol - yMin) / yRange;
        if (ratio < 0.0f) { ratio = 0.0f; }
        if (ratio > 1.0f) { ratio = 1.0f; }
        return (areaY + areaH - (ratio * areaH)).toNumber();
    }

    function timeToPixelX(time as Long, areaX as Number, areaW as Number,
                                  newestTime as Long, durationMs as Long) as Number {
        var elapsed = newestTime - time;
        if (elapsed < 0) { elapsed = 0l; }
        var ratio = 1.0f - (elapsed.toFloat() / durationMs.toFloat());
        if (ratio < 0.0f) { ratio = 0.0f; }
        if (ratio > 1.0f) { ratio = 1.0f; }
        return (areaX + ratio * areaW).toNumber();
    }

    function drawDashedLine(dc as Dc, x1 as Number, y1 as Number,
                                    x2 as Number, y2 as Number,
                                    dashLen as Number, gapLen as Number) as Void {
        var dx = x2 - x1;
        var dy = y2 - y1;
        var len = Math.sqrt((dx * dx + dy * dy).toFloat()).toNumber();
        if (len == 0) { return; }

        var ndx = dx.toFloat() / len;
        var ndy = dy.toFloat() / len;
        var pos = 0;
        var drawing = true;

        while (pos < len) {
            var segLen = drawing ? dashLen : gapLen;
            if (pos + segLen > len) { segLen = len - pos; }
            if (drawing) {
                var sx = (x1 + ndx * pos).toNumber();
                var sy = (y1 + ndy * pos).toNumber();
                var ex = (x1 + ndx * (pos + segLen)).toNumber();
                var ey = (y1 + ndy * (pos + segLen)).toNumber();
                dc.drawLine(sx, sy, ex, ey);
            }
            pos += segLen;
            drawing = !drawing;
        }
    }
}

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

module NeonRenderer {

    // Draw neon text with a glowing underline.
    function drawGlowText(dc as Dc, x as Number, y as Number,
                          font as FontDefinition, text as String,
                          justify as Number, textColor as Number,
                          glowColor as Number) as Void {
        // Crisp text
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, justify);

        // Glowing underline using alpha (same technique as graph lines)
        var dims = dc.getTextDimensions(text, font);
        var tw = dims[0];
        var th = dims[1];

        var lineX = x;
        if ((justify & Graphics.TEXT_JUSTIFY_CENTER) != 0) { lineX = x - tw / 2; }
        var lineY = y;
        if ((justify & Graphics.TEXT_JUSTIFY_VCENTER) != 0) { lineY = y + th / 2; }
        else { lineY = y + th; }
        lineY -= 16;

        var cr = (glowColor >> 16) & 0xFF;
        var cg = (glowColor >> 8) & 0xFF;
        var cb = glowColor & 0xFF;

        dc.setAntiAlias(true);
        // Wide dim halo
        dc.setStroke(Graphics.createColor(20, cr, cg, cb));
        dc.setPenWidth(8);
        dc.drawLine(lineX, lineY, lineX + tw, lineY);
        // Medium bloom
        dc.setStroke(Graphics.createColor(50, cr, cg, cb));
        dc.setPenWidth(6);
        dc.drawLine(lineX, lineY, lineX + tw, lineY);
        // Bright core
        dc.setStroke(Graphics.createColor(255, cr, cg, cb));
        dc.setPenWidth(1);
        dc.drawLine(lineX, lineY, lineX + tw, lineY);
        dc.setAntiAlias(false);
    }

    // Draw the retrowave perspective grid.
    // Horizontal lines with exponential spacing (bunched at horizon).
    // Vertical lines converging to center vanishing point.
    function drawPerspectiveGrid(dc as Dc, x as Number, y as Number,
                                  w as Number, h as Number,
                                  lineColor as Number) as Void {
        dc.setPenWidth(1);
        dc.setColor(lineColor, Graphics.COLOR_TRANSPARENT);

        var vanishX = x + w / 2;
        var vanishY = y;

        // Horizontal lines — exponential spacing
        var numH = 8;
        for (var i = 0; i <= numH; i++) {
            var ratio = i.toFloat() / numH;
            var lineY = y + (ratio * ratio * h).toNumber();
            dc.drawLine(x, lineY, x + w, lineY);
        }

        // Vertical lines converging to vanishing point
        var numV = 12;
        var bottomY = y + h;
        for (var i = 0; i <= numV; i++) {
            var bottomX = x + (i.toFloat() / numV * w).toNumber();
            dc.drawLine(vanishX, vanishY, bottomX, bottomY);
        }
    }

    // Draw a retrowave sun — segmented half-circle with horizontal slices.
    // Colors gradient from orange at top to hot pink at bottom.
    function drawSun(dc as Dc, cx as Number, horizonY as Number,
                     radius as Number) as Void {
        // Sun colors: top = warm orange, bottom = hot pink
        var colors = [0xFF6600, 0xFF4400, 0xFF2244, 0xFF0066] as Array;
        var numSlices = 8;
        var sliceGap = 3;

        for (var i = 0; i < numSlices; i++) {
            var ratio = i.toFloat() / numSlices;
            var colorIdx = (ratio * (colors.size() - 1)).toNumber();
            if (colorIdx >= colors.size()) { colorIdx = colors.size() - 1; }
            dc.setColor(colors[colorIdx] as Number, Graphics.COLOR_TRANSPARENT);

            // Each slice is a horizontal band of the circle above the horizon
            var sliceTop = horizonY - radius + (i * (radius * 2 / numSlices));
            var sliceBot = sliceTop + (radius * 2 / numSlices) - sliceGap;
            if (sliceBot > horizonY) { sliceBot = horizonY; }
            if (sliceTop > horizonY) { continue; }

            // Calculate chord width at each scanline
            for (var y = sliceTop.toNumber(); y < sliceBot.toNumber(); y++) {
                var dy = (y - horizonY + radius).toFloat();
                var dist = dy - radius;
                if (dist > 0) { dist = -dist; }
                var halfW = Math.sqrt((radius * radius - dist * dist).toFloat());
                if (halfW > 0) {
                    dc.drawLine((cx - halfW).toNumber(), y, (cx + halfW).toNumber(), y);
                }
            }
        }
    }

    // Draw a horizontal scanline effect (thin lines across area)
    function drawScanlines(dc as Dc, x as Number, y as Number,
                           w as Number, h as Number, spacing as Number,
                           color as Number) as Void {
        dc.setPenWidth(1);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var lineY = y + spacing;
        while (lineY < y + h) {
            dc.drawLine(x, lineY, x + w, lineY);
            lineY += spacing;
        }
    }
}

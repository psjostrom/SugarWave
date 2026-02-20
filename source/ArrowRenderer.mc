import Toybox.Graphics;
import Toybox.Lang;

module ArrowRenderer {

    function draw(dc as Dc, cx as Number, cy as Number, size as Number,
                  direction as Conversions.Direction, color as Number) as Void {
        if (direction == Conversions.DIRECTION_NONE) {
            return;
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);

        if (direction == Conversions.DIRECTION_DOUBLE_UP) {
            var s = (size * 0.6f).toNumber();
            var offset = (size * 0.22f).toNumber();
            drawSingleArrow(dc, cx - offset, cy, s, 0.0f, -1.0f);
            drawSingleArrow(dc, cx + offset, cy, s, 0.0f, -1.0f);
        } else if (direction == Conversions.DIRECTION_DOUBLE_DOWN) {
            var s = (size * 0.6f).toNumber();
            var offset = (size * 0.22f).toNumber();
            drawSingleArrow(dc, cx - offset, cy, s, 0.0f, 1.0f);
            drawSingleArrow(dc, cx + offset, cy, s, 0.0f, 1.0f);
        } else {
            var dx = 0.0f;
            var dy = 0.0f;

            if (direction == Conversions.DIRECTION_SINGLE_UP) {
                dx = 0.0f; dy = -1.0f;
            } else if (direction == Conversions.DIRECTION_FORTY_FIVE_UP) {
                dx = 0.707f; dy = -0.707f;
            } else if (direction == Conversions.DIRECTION_FLAT) {
                dx = 1.0f; dy = 0.0f;
            } else if (direction == Conversions.DIRECTION_FORTY_FIVE_DOWN) {
                dx = 0.707f; dy = 0.707f;
            } else if (direction == Conversions.DIRECTION_SINGLE_DOWN) {
                dx = 0.0f; dy = 1.0f;
            }

            drawSingleArrow(dc, cx, cy, size, dx, dy);
        }
    }

    function drawSingleArrow(dc as Dc, cx as Number, cy as Number,
                                     size as Number, dx as Float, dy as Float) as Void {
        var halfLen = size / 2;
        var headLen = size * 0.4f;
        var headWidth = size * 0.35f;
        var shaftWidth = size * 0.12f;

        var tipX = cx + (dx * halfLen).toNumber();
        var tipY = cy + (dy * halfLen).toNumber();

        var baseX = tipX - (dx * headLen).toNumber();
        var baseY = tipY - (dy * headLen).toNumber();

        var perpX = -dy;
        var perpY = dx;

        var leftX = baseX + (perpX * headWidth).toNumber();
        var leftY = baseY + (perpY * headWidth).toNumber();
        var rightX = baseX - (perpX * headWidth).toNumber();
        var rightY = baseY - (perpY * headWidth).toNumber();

        dc.fillPolygon([[tipX, tipY], [leftX, leftY], [rightX, rightY]]);

        var tailX = cx - (dx * halfLen).toNumber();
        var tailY = cy - (dy * halfLen).toNumber();

        var sw = (shaftWidth / 2).toNumber();
        if (sw < 1) { sw = 1; }

        var s1x = tailX + (perpX * sw).toNumber();
        var s1y = tailY + (perpY * sw).toNumber();
        var s2x = tailX - (perpX * sw).toNumber();
        var s2y = tailY - (perpY * sw).toNumber();
        var s3x = baseX - (perpX * sw).toNumber();
        var s3y = baseY - (perpY * sw).toNumber();
        var s4x = baseX + (perpX * sw).toNumber();
        var s4y = baseY + (perpY * sw).toNumber();

        dc.fillPolygon([[s1x, s1y], [s4x, s4y], [s3x, s3y], [s2x, s2y]]);
    }
}

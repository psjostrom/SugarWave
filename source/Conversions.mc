import Toybox.Graphics;
import Toybox.Lang;

module Conversions {

    enum Direction {
        DIRECTION_NONE = 0,
        DIRECTION_DOUBLE_UP = 1,
        DIRECTION_SINGLE_UP = 2,
        DIRECTION_FORTY_FIVE_UP = 3,
        DIRECTION_FLAT = 4,
        DIRECTION_FORTY_FIVE_DOWN = 5,
        DIRECTION_SINGLE_DOWN = 6,
        DIRECTION_DOUBLE_DOWN = 7
    }

    const GRAPH_Y_MIN = 2.0f;
    const GRAPH_Y_MAX = 20.0f;
    const MGDL_TO_MMOL = 18.018f;
    const STALE_MINUTES = 10;

    // Retrowave neon palette — AMOLED optimized (bright neons on pure black)
    const COLOR_NEON_CYAN = 0x00FFFF;
    const COLOR_NEON_PINK = 0xFF0066;
    const COLOR_NEON_PURPLE = 0x9900FF;
    const COLOR_NEON_ORANGE = 0xFF6600;
    const COLOR_NEON_RED = 0xFF5555;
    const COLOR_NEON_BLUE = 0x0088FF;

    // Bright purple for date text — WCAG AA on black (5.9:1)
    const COLOR_DATE = 0xBB66FF;

    // Dim glow halos (÷2 per channel — visible on AMOLED)
    const COLOR_DIM_CYAN = 0x007F7F;
    const COLOR_DIM_PINK = 0x7F0033;
    const COLOR_DIM_PURPLE = 0x4D007F;
    const COLOR_DIM_ORANGE = 0x7F3300;
    const COLOR_DIM_RED = 0x7F2A2A;

    // BG zone colors
    const COLOR_IN_RANGE = COLOR_NEON_CYAN;
    const COLOR_HIGH = COLOR_NEON_ORANGE;
    const COLOR_LOW = COLOR_NEON_RED;

    // Graph colors
    const COLOR_GRAPH_DOT_IN_RANGE = COLOR_NEON_CYAN;
    const COLOR_GRAPH_DOT_HIGH = COLOR_NEON_ORANGE;
    const COLOR_GRAPH_DOT_LOW = COLOR_NEON_RED;
    const COLOR_GRAPH_LINE = COLOR_DIM_PURPLE;
    const COLOR_GRAPH_LOW_ZONE = 0x330011;
    const COLOR_GRAPH_HIGH_LINE = COLOR_NEON_ORANGE;
    const COLOR_GRID = 0x5500AA;

    // Stale colors
    const COLOR_STALE = COLOR_NEON_RED;
    const COLOR_STALE_WARNING = COLOR_NEON_ORANGE;

    function mgdlToMmol(mgdl as Float) as Float {
        return mgdl / MGDL_TO_MMOL;
    }

    function directionFromString(dir as String?) as Direction {
        if (dir == null) { return DIRECTION_NONE; }
        if (dir.equals("DoubleUp")) { return DIRECTION_DOUBLE_UP; }
        if (dir.equals("SingleUp")) { return DIRECTION_SINGLE_UP; }
        if (dir.equals("FortyFiveUp")) { return DIRECTION_FORTY_FIVE_UP; }
        if (dir.equals("Flat")) { return DIRECTION_FLAT; }
        if (dir.equals("FortyFiveDown")) { return DIRECTION_FORTY_FIVE_DOWN; }
        if (dir.equals("SingleDown")) { return DIRECTION_SINGLE_DOWN; }
        if (dir.equals("DoubleDown")) { return DIRECTION_DOUBLE_DOWN; }
        return DIRECTION_NONE;
    }

    function bgColor(mmol as Float, low as Float, high as Float) as Number {
        if (mmol < low) { return COLOR_LOW; }
        if (mmol > high) { return COLOR_HIGH; }
        return COLOR_IN_RANGE;
    }

    function graphDotColor(mmol as Float, low as Float, high as Float) as Number {
        if (mmol < low) { return COLOR_GRAPH_DOT_LOW; }
        if (mmol > high) { return COLOR_GRAPH_DOT_HIGH; }
        return COLOR_GRAPH_DOT_IN_RANGE;
    }

    function staleColor(minutes as Number) as Number {
        if (minutes < 0) { return COLOR_NEON_CYAN; }
        if (minutes < 5) { return COLOR_NEON_CYAN; }
        if (minutes < STALE_MINUTES) { return COLOR_STALE_WARNING; }
        return COLOR_STALE;
    }

    function glowColor(bright as Number) as Number {
        var r = ((bright >> 16) & 0xFF) / 2;
        var g = ((bright >> 8) & 0xFF) / 2;
        var b = (bright & 0xFF) / 2;
        return (r << 16) | (g << 8) | b;
    }

    function parseFloat(value) as Float {
        if (value instanceof Float) {
            return value as Float;
        } else if (value instanceof Double) {
            return (value as Double).toFloat();
        } else if (value instanceof Number) {
            return (value as Number).toFloat();
        }
        return 0.0f;
    }

    function parseLong(value) as Long {
        if (value instanceof Long) {
            return value as Long;
        } else if (value instanceof Double) {
            return (value as Double).toLong();
        } else if (value instanceof Float) {
            return (value as Float).toDouble().toLong();
        } else if (value instanceof Number) {
            return (value as Number).toLong();
        }
        return 0l;
    }

    function formatDelta(deltaMmol as Float) as String {
        if (deltaMmol >= 0) {
            return "+" + deltaMmol.format("%.1f");
        }
        return deltaMmol.format("%.1f");
    }
}
